import logging
import os
import socket
from datetime import datetime, timezone
from pathlib import Path


def main() -> None:
    logging.basicConfig(
        level=os.getenv("LOG_LEVEL", "INFO"),
        format="%(asctime)s %(levelname)s %(message)s",
    )

    host = os.getenv("COT_SINK_HOST", "0.0.0.0")
    port = int(os.getenv("COT_SINK_PORT", "9001"))
    output_dir = Path(os.getenv("COT_SINK_DIR", "/data"))
    output_dir.mkdir(parents=True, exist_ok=True)

    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.bind((host, port))
    logging.info("CoT sink listening on %s:%s", host, port)

    counter = 0
    while True:
        data, addr = sock.recvfrom(65535)
        counter += 1
        payload = data.decode("utf-8", errors="replace")
        logging.info("Received %s bytes from %s", len(data), addr)
        logging.info("CoT payload\n%s", payload)
        timestamp = datetime.now(tz=timezone.utc).strftime("%Y%m%dT%H%M%SZ")
        out_path = output_dir / f"cot-{timestamp}-{counter}.xml"
        out_path.write_text(payload, encoding="utf-8")


if __name__ == "__main__":
    main()