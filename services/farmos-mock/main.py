import json
import logging
import os
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path


class MockHandler(BaseHTTPRequestHandler):
    def _write_response(self, status: int, body: dict) -> None:
        payload = json.dumps(body).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def do_POST(self) -> None:  # noqa: N802
        length = int(self.headers.get("Content-Length", "0"))
        body = self.rfile.read(length)
        decoded = body.decode("utf-8", errors="replace")
        timestamp = datetime.now(tz=timezone.utc).strftime("%Y%m%dT%H%M%SZ")
        output_dir = Path(os.getenv("FARMOS_MOCK_DIR", "/data"))
        output_dir.mkdir(parents=True, exist_ok=True)
        out_path = output_dir / f"farmos-{timestamp}-{self.client_address[0].replace(':', '_')}.json"
        out_path.write_text(decoded, encoding="utf-8")
        logging.info("Recorded farmOS mock POST to %s", out_path)
        self._write_response(201, {"status": "ok", "path": self.path})

    def log_message(self, format: str, *args: object) -> None:
        logging.info("%s - %s", self.client_address[0], format % args)


def main() -> None:
    logging.basicConfig(
        level=os.getenv("LOG_LEVEL", "INFO"),
        format="%(asctime)s %(levelname)s %(message)s",
    )

    host = os.getenv("FARMOS_MOCK_HOST", "0.0.0.0")
    port = int(os.getenv("FARMOS_MOCK_PORT", "8000"))
    server = HTTPServer((host, port), MockHandler)
    logging.info("farmOS mock listening on %s:%s", host, port)
    server.serve_forever()


if __name__ == "__main__":
    main()