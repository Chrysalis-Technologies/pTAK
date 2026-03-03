import os
import re
import time
import zipfile
from collections import deque, defaultdict
from html.parser import HTMLParser
from urllib.parse import urljoin, urlparse, urldefrag, unquote, parse_qs
from urllib.request import Request, urlopen
from urllib.error import HTTPError

try:
    import requests
except ModuleNotFoundError:
    requests = None

try:
    from tqdm import tqdm
except ModuleNotFoundError:
    def tqdm(iterable=None, **kwargs):
        return iterable if iterable is not None else []

# =========================
# Configuration
# =========================

FOLDER = "NY_Small_Farm_Library_2019plus"
ZIP_PATH = f"{FOLDER}.zip"

USER_AGENT = (
    "NY-Small-Farm-Library/1.0 "
    "(Upstate NY small farm PDF library builder; polite crawler)"
)

REQUEST_TIMEOUT = 45
CRAWL_DELAY_SECONDS = 0.20
DOWNLOAD_DELAY_SECONDS = 1.0

SEED_URLS = [
    "https://smallfarms.cornell.edu/resources/guides/",
    "https://attra.ncat.org/publication-library/",
    "https://nofany.org/resources/library/",
    "https://www.uvm.edu/extension/newfarmerproject/resources/search-resources",
    "https://www.sare.org/resources/",
    "https://www.sheepandgoat.com/ebooks",
    "https://www.sheepandgoat.com/",
    "https://landforgood.org/resources/",
    "https://extension.psu.edu/business-and-operations/starting-a-farm/ag-alternatives",
    "https://rodaleinstitute.org/education/resources/",
    "https://eorganic.org/",
]

ALLOWED_DOMAIN_SUFFIXES = [
    "smallfarms.cornell.edu",
    "attra.ncat.org",
    "ncat.org",
    "nofany.org",
    "uvm.edu",
    "sare.org",
    "sheepandgoat.com",
    "landforgood.org",
    "extension.psu.edu",
    "rodaleinstitute.org",
    "eorganic.org",
]

CRAWL_PATH_PREFIXES = {
    "smallfarms.cornell.edu": ["/resources/guides/", "/wp-content/"],
    "attra.ncat.org": [
        "/publication-library/",
        "/publication-index/",
        "/publication/",
        "/wp-content/",
    ],
    "nofany.org": ["/resources/", "/wp-content/"],
    "uvm.edu": ["/extension/newfarmerproject/resources/"],
    "sare.org": ["/resources/", "/wp-content/", "/publications/"],
    "sheepandgoat.com": ["/"],
    "landforgood.org": ["/resources/", "/get-resource", "/wp-content/"],
    "extension.psu.edu": ["/business-and-operations/starting-a-farm/ag-alternatives"],
    "rodaleinstitute.org": ["/education/resources/", "/wp-content/"],
    "eorganic.org": ["/"],
}

INCLUDE_KEYWORDS = [
    "sheep",
    "goat",
    "lamb",
    "small ruminant",
    "pasture",
    "graz",
    "forage",
    "vegetable",
    "market garden",
    "field crop",
    "business plan",
    "enterprise",
    "budget",
    "marketing",
    "direct market",
    "land access",
    "farmland",
    "lease",
    "succession",
    "northeast",
    "new york",
    "vermont",
    "pennsylvania",
]

EXCLUDE_KEYWORDS = [
    "poultry",
    "chicken",
    "swine",
    "hog",
    "cattle",
    "aquaculture",
    "cannabis",
]

YEAR_MIN_ARTICLE = 2019
YEAR_MIN_BOOK = 2001

PDF_LIST = []

YEAR_RE = re.compile(r"(?<!\d)(19\d{2}|20\d{2})(?!\d)")


if requests is None:
    class _CompatResponse:
        def __init__(self, handle, final_url):
            self._handle = handle
            self.url = final_url
            self.status_code = int(getattr(handle, "status", 200) or 200)
            self._body = None
            headers = {}
            try:
                raw = handle.headers.items()
            except:
                raw = []
            for k, v in raw:
                headers[k] = v
                headers[k.lower()] = v
                headers[k.title()] = v
            self.headers = headers

        @property
        def text(self):
            if self._body is None:
                self._body = self._handle.read()
            content_type = self.headers.get("Content-Type", "")
            match = re.search(r"charset=([A-Za-z0-9._-]+)", content_type, flags=re.I)
            encoding = match.group(1) if match else "utf-8"
            return self._body.decode(encoding, errors="replace")

        def iter_content(self, chunk_size=8192):
            if self._body is not None:
                for i in range(0, len(self._body), chunk_size):
                    yield self._body[i:i + chunk_size]
                return
            while True:
                chunk = self._handle.read(chunk_size)
                if not chunk:
                    break
                yield chunk

        def raise_for_status(self):
            if self.status_code >= 400:
                raise RuntimeError(f"HTTP {self.status_code} for {self.url}")


    class _CompatSession:
        def __init__(self):
            self.headers = {}

        def get(self, url, stream=False, timeout=REQUEST_TIMEOUT, allow_redirects=True):
            req = Request(url, headers=self.headers, method="GET")
            try:
                handle = urlopen(req, timeout=timeout)
                final_url = handle.geturl() or url
                return _CompatResponse(handle, final_url)
            except HTTPError as e:
                final_url = e.geturl() or url
                return _CompatResponse(e, final_url)


    class _RequestsShim:
        Session = _CompatSession


    requests = _RequestsShim()


def _clean(s):
    return re.sub(r"\s+", " ", (s or "").strip())


def _is_allowed(url):
    try:
        netloc = urlparse(url).netloc.lower()
        return any(netloc.endswith(s) for s in ALLOWED_DOMAIN_SUFFIXES)
    except:
        return False


def _path_allowed_for_crawl(url):
    try:
        parsed = urlparse(url)
        netloc = parsed.netloc.lower()
        path = parsed.path or "/"
    except:
        return False

    for domain, prefixes in CRAWL_PATH_PREFIXES.items():
        if netloc == domain or netloc.endswith("." + domain):
            return any(path.startswith(prefix) for prefix in prefixes)
    return False


def _normalize(url, base=None):
    if base:
        url = urljoin(base, url)
    url, _ = urldefrag(url)
    if url.startswith("http://"):
        url = "https://" + url[7:]
    return url


def _looks_like_pdf_link(url, text):
    parsed = urlparse(url)
    path = (parsed.path or "").lower()
    whole = url.lower()
    text_l = (text or "").lower()

    if path.endswith(".pdf") or ".pdf" in whole:
        return True

    qs = parse_qs(parsed.query)
    for values in qs.values():
        for v in values:
            if ".pdf" in (v or "").lower():
                return True

    if "pdf" in text_l and any(x in whole for x in ["download", "file", "attachment", "document"]):
        return True

    return False


def _is_relevant(text):
    t = (text or "").lower()
    if any(x in t for x in EXCLUDE_KEYWORDS):
        return False
    return any(x in t for x in INCLUDE_KEYWORDS)


def _extract_year(text):
    years = [int(y) for y in YEAR_RE.findall(text or "")]
    return max(years) if years else None


class Parser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.links = []
        self._in_a = False
        self._href = ""
        self._text = []

    def handle_starttag(self, tag, attrs):
        if tag.lower() == "a":
            attrs = dict(attrs)
            if "href" in attrs:
                self._in_a = True
                self._href = attrs["href"]
                self._text = []

    def handle_endtag(self, tag):
        if tag.lower() == "a" and self._in_a:
            text = _clean(" ".join(self._text))
            self.links.append((self._href, text))
            self._in_a = False

    def handle_data(self, data):
        if self._in_a:
            self._text.append(data)


def _build_filename(url, title):
    parsed = urlparse(url)
    from_path = unquote(os.path.basename(parsed.path))
    if from_path.lower().endswith(".pdf"):
        return from_path

    qs = parse_qs(parsed.query)
    for key in ["file", "filename", "download", "attachment", "doc", "document"]:
        for value in qs.get(key, []):
            name = unquote(os.path.basename(value))
            if name.lower().endswith(".pdf"):
                return name

    safe_title = re.sub(r"[^A-Za-z0-9._-]+", "_", title or "").strip("._")
    return (safe_title or "document") + ".pdf"


def _unique_path(folder, filename):
    root, ext = os.path.splitext(filename)
    ext = ext or ".pdf"
    candidate = filename
    n = 2
    path = os.path.join(folder, candidate)
    while os.path.exists(path):
        candidate = f"{root}_{n}{ext}"
        path = os.path.join(folder, candidate)
        n += 1
    return path


def crawl():
    session = requests.Session()
    session.headers.update({"User-Agent": USER_AGENT})

    visited = set()
    queue = deque()
    queued = set()
    for seed in SEED_URLS:
        norm = _normalize(seed)
        queue.append(norm)
        queued.add(norm)
    candidates = {}

    while queue:
        url = queue.popleft()
        url = _normalize(url)
        if url in visited or not _is_allowed(url):
            continue
        visited.add(url)

        try:
            r = session.get(url, timeout=REQUEST_TIMEOUT)
            if "text/html" not in r.headers.get("Content-Type", ""):
                continue
            parser = Parser()
            parser.feed(r.text)
        except:
            continue

        for href, text in parser.links:
            full = _normalize(href, base=url)
            if not _is_allowed(full):
                continue

            if _looks_like_pdf_link(full, text) and _is_relevant(text + full):
                candidates[full] = text or os.path.basename(full)
            elif _path_allowed_for_crawl(full):
                if full not in visited and full not in queued:
                    queue.append(full)
                    queued.add(full)

        time.sleep(CRAWL_DELAY_SECONDS)

    return candidates


def download_and_filter(candidates):
    session = requests.Session()
    session.headers.update({"User-Agent": USER_AGENT})

    os.makedirs(FOLDER, exist_ok=True)
    qualified = []

    for url, title in tqdm(candidates.items(), desc="Downloading PDFs"):
        filename = _build_filename(url, title)
        path = _unique_path(FOLDER, filename)

        try:
            r = session.get(url, stream=True, timeout=REQUEST_TIMEOUT, allow_redirects=True)
            r.raise_for_status()
            content_type = r.headers.get("Content-Type", "").lower()
            final_url = (r.url or "").lower()
            if "pdf" not in content_type and ".pdf" not in final_url:
                raise ValueError("Resolved resource is not a PDF")

            with open(path, "wb") as f:
                for chunk in r.iter_content(8192):
                    f.write(chunk)

            year = _extract_year(title + " " + url + " " + final_url)
            if (year is None) or (year >= YEAR_MIN_ARTICLE):
                qualified.append({"title": title, "url": url, "year": year})
            else:
                os.remove(path)

        except:
            if os.path.exists(path):
                os.remove(path)

        time.sleep(DOWNLOAD_DELAY_SECONDS)

    return qualified


def zip_folder():
    with zipfile.ZipFile(ZIP_PATH, "w", zipfile.ZIP_DEFLATED) as zf:
        for root, _, files in os.walk(FOLDER):
            for file in files:
                full = os.path.join(root, file)
                rel = os.path.relpath(full, FOLDER)
                zf.write(full, rel)


def main():
    print("Crawling specified sites...")
    candidates = crawl()
    print(f"Found {len(candidates)} candidate PDFs.")

    global PDF_LIST
    PDF_LIST = download_and_filter(candidates)

    zip_folder()

    print(f"\nDONE. {len(PDF_LIST)} PDFs saved.")
    print(f"Folder: {FOLDER}")
    print(f"Zip: {ZIP_PATH}")


if __name__ == "__main__":
    main()
