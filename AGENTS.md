# AGENTS

## Goal
Configure TLS certificates between the Docker FreeTAKServer container and the WinTAK desktop client.

## Files and tasks
- `scripts/gen-fts-certs.ps1` generates CA, server, and client certs into `fts-certs/`.
- `fts-certs` should include `ca.pem` and `server.pem` (copies of the `.crt` files) and be mounted read/write.
- `docker-compose.yml` mounts `fts-certs` into the container and sets `FTS_TLS`, `FTS_CERTS_PATH`, `FTS_SERVER_PEMDIR`, `FTS_SERVER_KEYDIR`, `FTS_CADIR`, and `FTS_CAKEYDIR`.
- VS Code tasks: `fts:compose:up`, `fts:gen-certs`, `fts:test`.

## Procedure
1. Start the stack: `docker compose up -d` (or `fts:compose:up`).
2. Generate certs: `pwsh ./scripts/gen-fts-certs.ps1 -ClientCommonName WinTAK-Paul`
   - Use `-Force` if you need to regenerate.
   - Outputs: `fts-certs/ca.crt`, `fts-certs/server.crt`, `fts-certs/server.key`, `fts-certs/WinTAK-Paul.p12`.
   - Server cert SANs include `freetakserver`, `localhost`, `127.0.0.1`. Use one of these for the client connection to avoid hostname mismatch.
3. Ensure PEM copies exist for FTS defaults: `Copy-Item fts-certs/ca.crt fts-certs/ca.pem` and `Copy-Item fts-certs/server.crt fts-certs/server.pem`.
4. Restart the server to load new certs: `docker compose restart freetakserver`.
5. Configure WinTAK:
   - Use `WinTAK-Paul-NoPwd.p12` for the client identity and `FTS-CA.p12` for the truststore.
   - Add a server connection to `127.0.0.1` port `8089` with TLS enabled and select the imported identity.
6. Verify: run `pwsh ./scripts/test-fts.ps1` and confirm port `8089` is open.

## Notes
- TLS is enabled in `docker-compose.yml` via `FTS_TLS` and the cert paths under `/certs`.
- `fts-certs` must be read/write so FreeTAKServer can create `server.key.unencrypted`.
- The repo mounts patched SSL controllers from `overrides/` to avoid a CRL requirement at startup. Keep those mounts if you rebuild the image or regenerate a CRL at `fts-certs/FTS_CRL.json`.
- If WinTAK complains about a cert password, switch to `WinTAK-Paul-NoPwd.p12` and re-import it.
- After TLS is working, consider removing ports `8087` and `8080` from `docker-compose.yml` to enforce TLS-only access.
