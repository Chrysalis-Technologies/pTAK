"""
Download a set of public military planning PDFs into the repository.

Usage:
    python tools/download_mil_planning_docs.py
"""

import sys
from pathlib import Path
from urllib.parse import urlsplit, unquote

try:
    import requests
except ImportError:  # pragma: no cover - runtime dependency notice
    print("Missing required dependency 'requests'. Install with: pip install requests")
    sys.exit(1)

HEADERS = {"User-Agent": "Mozilla/5.0 (compatible; mil-doc-downloader/1.0)"}


DOCS = [
    {
        "url": "https://rdl.train.army.mil/catalog-ws/view/arimanagingcomplexproblems/downloads/Army_Design_Methodology_ATP_5-0.1_July_2015.pdf",
        "label": "ATP 5-0.1 Army Design Methodology",
    },
    {
        "url": "https://www.safety.marines.mil/Portals/92/Ground%20Safety%20for%20Marines%20(GSM)/References%20Tab/JP%205-0%20Joint%20Planning%20PDF.pdf?ver=EOLLxznFWQ7soVITZGYa8Q%3D%3D",
        "label": "JP 5-0 Joint Planning (2020)",
    },
    {
        "url": "https://stephengates.com/ADM/FM-JUL22.pdf",
        "label": "FM 5-0 The Operations Process (2022)",
    },
    {
        "url": "https://www.atu.edu/rotc/docs/8_fm5_0.pdf",
        "label": "FM 5-0 The Operations Process (2010)",
    },
    {
        "url": "https://www.milsci.ucsb.edu/sites/default/files/sitefiles/fm6_0.pdf",
        "label": "FM 6-0 Mission Command",
    },
    {
        "url": "https://armyuniversity.edu/cgsc/cgss/files/15-06_0.pdf",
        "label": "MDMP Handbook 15-06",
    },
    {
        "url": "https://api.army.mil/e2/c/downloads/2023/11/17/f7177a3c/23-07-594-military-decision-making-process-nov-23-public.pdf",
        "label": "MDMP bulletin 23-07-594 (Nov 2023)",
    },
    {
        "url": "https://www.elon.edu/assets/docs/rotc/FM%205-0%20Army%20Planning%20and%20Orders%20Production%20.pdf",
        "label": "FM 5-0 (2005) Army Planning and Orders Production",
    },
    {
        "url": "https://upload.wikimedia.org/wikipedia/en/c/ce/APP-06_E_1.pdf",
        "label": "APP-06(E)(1) NATO Joint Military Symbology (2017)",
    },
    {
        "url": "https://guallah.com/archive/archive_files/archive_upload_9.pdf",
        "label": "APP-6(C) NATO Joint Military Symbology (2011) mirror",
    },
    {
        "url": "https://www.jcs.mil/portals/36/documents/doctrine/other_pubs/ms_2525d.pdf",
        "label": "MIL-STD-2525D Joint Military Symbology",
    },
    {
        "url": "https://www.boisestate.edu/sps-militaryscience/wp-content/uploads/sites/123/2014/04/symbology.pdf",
        "label": "Military Symbology summary (Boise State)",
    },
    {
        "url": "https://theforge.defence.gov.au/sites/default/files/adfp_5.0.1_joint_military_appreciation_process_ed2_al3_1.pdf",
        "label": "ADFP 5.0.1 Joint Military Appreciation Process (JMAP)",
    },
]


def derive_filename(url: str) -> str:
    """Extract a filesystem-safe filename from the URL."""
    parsed = urlsplit(url)
    name = Path(parsed.path).name or "download"
    return unquote(name)


def download_file(url: str, dest: Path) -> None:
    if dest.exists() and dest.stat().st_size > 0:
        print(f"SKIP {dest.name}")
        return

    try:
        with requests.get(url, stream=True, timeout=120, headers=HEADERS) as response:
            if response.status_code != 200:
                print(f"ERROR {response.status_code} downloading {url}")
                return

            dest.parent.mkdir(parents=True, exist_ok=True)
            with dest.open("wb") as fh:
                for chunk in response.iter_content(chunk_size=8192):
                    if chunk:  # filter out keep-alive chunks
                        fh.write(chunk)
        print(f"OK   {dest.name}")
    except requests.exceptions.RequestException as exc:
        print(f"ERROR fetching {url}: {exc}")


def main() -> None:
    repo_root = Path(__file__).resolve().parent.parent
    target_dir = repo_root / "mil_planning_templates"

    for entry in DOCS:
        url = entry["url"]
        filename = derive_filename(url)
        destination = target_dir / filename
        download_file(url, destination)


if __name__ == "__main__":
    main()
