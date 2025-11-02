# WinTAK Workspace

This repository collects local tooling and configuration used alongside WinTAK and related integrations.

## Run TAK locally

Prerequisites:
- Install Docker Desktop and ensure it is set to Linux container mode.
- (Windows) Enable and configure WSL 2 for best performance.

Start and stop the stack:
- In VS Code, open the Command Palette and run `Tasks: Run Task`, then choose `fts:compose:up` or `fts:compose:down`.
- Alternatively, run the corresponding tasks from the status bar task runner if available.

 Smoke-test the FreeTAKServer API:
- Run the `fts:test` task, which invokes `scripts/test-fts.ps1` and verifies critical ports.
- The FreeTAKServer web service is available at `http://localhost:8080/` when the stack is running.

Connect WinTAK:
- Add a TAK server connection pointing to `127.0.0.1:8087` (unencrypted) to validate connectivity.
- After configuring certificates, switch the client to the TLS endpoints on ports `8089` or `8443`.

## Run TAK locally with TLS

- Prerequisites: Docker Desktop (Linux containers), OpenSSL available in `PATH`, and PowerShell 7 or later.
- Start services with the **fts:compose:up** task.
- Generate CA, server, and client certificates with **fts:gen-certs** (writes `fts-certs\ca.crt`, `server.crt/server.key`, and `WinTAK-Paul.p12`).
- Apply new certificates by running `docker compose restart freetakserver`.
- Validate connectivity using the **fts:test** task.
- In WinTAK, import `fts-certs\WinTAK-Paul.p12` (using the export password), trust `fts-certs\ca.crt`, and connect to `127.0.0.1:8089` with TLS enabled.
- Hardening tip: remove ports `8087` and `8080` from `docker-compose.yml` and re-run **fts:compose:up** to enforce TLS-only access once clients are migrated.
