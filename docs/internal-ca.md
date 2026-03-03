# Unified Internal PKI (pTAK)

This repo now uses a unified internal PKI toolkit with an **offline root CA** and an **issuing intermediate CA**.

The toolkit is implemented by:
- `scripts/ptak-ca.sh` (bash core)
- `scripts/ptak-ca.ps1` (PowerShell wrapper)
- `scripts/ptak-ca-verify.sh` (validation helper)

## Design

- Root CA private key:
  - `root/private/root-ca.key.pem`
  - RSA-4096, encrypted
  - never copied into `fts-certs/` or `mqtt-certs/`
- Issuing CA private key:
  - `issuing/private/issuing-ca.key.pem`
  - RSA-4096, encrypted
  - never copied into runtime cert directories by default
- Leaf keys:
  - default RSA-2048
  - optional `--rsa-bits 4096`

## Persistent CA Storage (WSL-safe default)

Default CA state path:
- `${PTAK_CA_DIR:-$HOME/.ptak/internal-ca}`

Because this repository is under `/mnt/c/...`, CA state is stored on the Linux filesystem by default (`~/.ptak/internal-ca`) for better key permissions and reliability.

`init` creates/repairs a symlink in the repo:
- `secrets/internal-ca -> $PTAK_CA_DIR`

To override the location:
```bash
export PTAK_CA_DIR=/path/to/your/ca-state
bash ./scripts/ptak-ca.sh init
```

## Directory Layout

```text
$PTAK_CA_DIR/
  root/
    certs/root-ca.crt
    private/root-ca.key.pem
  issuing/
    certs/issuing-ca.crt
    private/issuing-ca.key.pem
    db/index.txt
    db/serial
    db/crlnumber
    db/newcerts/
  online/
    certs/fts-online-ca.crt
    private/fts-online-ca.key.pem
    db/...
  issued/
    server/<name>.crt|key|csr|chain.crt
    client/<name>.crt|key|csr|chain.crt|p12
  public/
    root-ca.crt
    issuing-ca.crt
    ca-chain.crt
    ca.crl.pem
  backups/
    internal-ca-<timestamp>.tar.gz.enc
    internal-ca-<timestamp>.tar.gz.enc.sha256
  .ca-passphrase
```

## Initialize CA

```bash
bash ./scripts/ptak-ca.sh init
```

Force re-initialize (moves old CA subdirs into timestamped backup):
```bash
bash ./scripts/ptak-ca.sh init --force
```

Show status/fingerprints:
```bash
bash ./scripts/ptak-ca.sh show
```

## Issue New Certificates

### Server cert

```bash
bash ./scripts/ptak-ca.sh issue-server mqtt-server \
  --cn mqtt-broker \
  --san "mqtt-broker,mosquitto,localhost,127.0.0.1" \
  --out "$HOME/.ptak/internal-ca/issued/server"
```

### Client cert

```bash
bash ./scripts/ptak-ca.sh issue-client WinTAK-Paul \
  --cn WinTAK-Paul \
  --san "WinTAK-Paul" \
  --out "$HOME/.ptak/internal-ca/issued/client" \
  --p12
```

Passwordless PKCS#12 is opt-in only:
```bash
bash ./scripts/ptak-ca.sh issue-client Device01 \
  --cn Device01 \
  --out "$HOME/.ptak/internal-ca/issued/client" \
  --p12 --no-p12-password
```

## Provision Runtime Compatibility Artifacts

Provision both MQTT + FTS + WinTAK artifacts (always backs up current runtime cert dirs first):
```bash
bash ./scripts/ptak-ca.sh provision
```

Outputs are written to existing expected paths:
- MQTT:
  - `mqtt-certs/ca.crt`
  - `mqtt-certs/server.crt`
  - `mqtt-certs/server.key`
- FreeTAKServer / WinTAK:
  - `fts-certs/ca.pem`
  - `fts-certs/server.pem`
  - `fts-certs/server.key`
  - `fts-certs/WinTAK-<name>.crt|key|p12`
  - `fts-certs/client.pem|client.key`

By default, no CA private key is copied into runtime cert directories.

### Dangerous mode: online CA key for FTS

If runtime signing/enrollment truly requires an online CA key, use:
```bash
bash ./scripts/ptak-ca.sh provision --allow-online-ca-key
```

This creates a dedicated online intermediate and copies **only** that key to `fts-certs/ca.key`.
It never copies root key or main issuing key.

Risk: any compromise of runtime-mounted cert paths can expose online signing capability.

## Revocation and CRL

Revoke by cert name or path:
```bash
bash ./scripts/ptak-ca.sh revoke WinTAK-Paul
bash ./scripts/ptak-ca.sh revoke /absolute/path/to/cert.crt --reason keyCompromise
```

Generate/update CRL:
```bash
bash ./scripts/ptak-ca.sh crl
```

CRL output:
- `public/ca.crl.pem`

Online CA CRL (if online CA is used):
```bash
bash ./scripts/ptak-ca.sh crl --ca online
```

### Mosquitto CRL note

Mosquitto supports CRL with `crlfile` on TLS listeners. Example:
```conf
cafile /mosquitto/certs/ca.crt
crlfile /mosquitto/certs/ca.crl.pem
```

## Backups and Restore

Create encrypted CA backup + checksum:
```bash
bash ./scripts/ptak-ca.sh backup
```

Use a specific backup password file:
```bash
bash ./scripts/ptak-ca.sh backup --backup-password-file ~/.ptak/backup.pass
```

Default backup excludes `.ca-passphrase`.
Include it explicitly only if needed:
```bash
bash ./scripts/ptak-ca.sh backup --include-passphrase
```

Verify backup integrity:
```bash
sha256sum -c "$PTAK_CA_DIR/backups/<file>.sha256"
```

Restore example:
```bash
openssl enc -d -aes-256-cbc -pbkdf2 -in internal-ca-<ts>.tar.gz.enc -out internal-ca-<ts>.tar.gz
mkdir -p "$PTAK_CA_DIR"
tar -xzf internal-ca-<ts>.tar.gz -C "$PTAK_CA_DIR"
```

## Trust Distribution

- `public/root-ca.crt` is the trust anchor you distribute to clients.
- `public/ca-chain.crt` is `issuing-ca + root-ca` and is used for chain presentation/verification.
- For servers, provide leaf cert plus chain as needed (`server.pem` includes server cert + chain in FTS compatibility output).

## Validation

Run basic cert validation checks:
```bash
bash ./scripts/ptak-ca-verify.sh
```

Checks include:
- `openssl verify` against chain
- EKU/KU/SAN checks for MQTT server, FTS server, and FTS client certs

## Legacy Script Compatibility

Existing scripts now delegate to `ptak-ca` while preserving their parameter signatures:
- `scripts/gen-fts-certs.ps1`
- `scripts/gen-mqtt-certs.ps1`
- `scripts/gen-mqtt-certs.sh`

## WSL Permission Guidance

- Keep CA state under Linux filesystem (`~/.ptak/...`), not `/mnt/c/...`.
- Ensure key/passphrase files remain mode `600`.
- Avoid storing CA passphrase in shell history.
- Use `PTAK_CA_DIR` only when you intentionally relocate CA state.
