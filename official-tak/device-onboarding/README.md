# Device Onboarding Kit

Everything you need to get new clients (WinTAK/iTAK on iOS and Meshtastic bridges) talking to the official TAK server lives here.

The high-level flow for any new device is:

1. **Mint a client certificate** using the Vivarium CA.
2. **Grant the cert proper TAK roles** so it can authenticate.
3. **Deliver the .p12/.pem bundle** to the device and import it alongside the `ca.pem`.
4. **Point the client at** `takserver` (`127.0.0.1` per hosts file) on port `8089` for COT and `9443` for the admin UI.

---

## 1. Generate a new client certificate

Run these commands from the repo root with the Docker stack up. Replace `DEVICE_NAME` and `ClientPass2025!` with values that make sense for the device you're onboarding.

```powershell
$env:CAPASS = 'TakCaPass2025!'
$env:PASS   = 'ClientPass2025!'         # password that will protect the .p12
docker exec docker-takserver-1 bash -lc "cd /opt/tak/certs && ./makeCert.sh client DEVICE_NAME"
```

Artifacts are written to `/opt/tak/certs/files` inside the container, which maps to:

```
official-tak/takdata/certs/files/DEVICE_NAME.pem
official-tak/takdata/certs/files/DEVICE_NAME.key
official-tak/takdata/certs/files/DEVICE_NAME.p12
```

Promote the new cert to the proper TAK role (admin, operator, etc.):

```powershell
docker exec docker-takserver-1 java -jar /opt/tak/utils/UserManager.jar certmod `
    -A "/opt/tak/certs/files/DEVICE_NAME.pem" `
    -R ROLE_OPERATOR
```

> Tip: keep the CA (`ca.pem`) with the exported bundle. Every new client needs to trust it.

---

## 2. Onboard an iPhone/iPad (iTAK)

1. Copy `DEVICE_NAME.p12` plus `ca.pem` from `official-tak\takdata\certs\files`.
2. AirDrop/email the files to the device (or drop them into iCloud Files).
3. Install `ca.pem` first (`Settings → Profile Downloaded → Install`) so iOS trusts the Vivarium CA.
4. Install `DEVICE_NAME.p12` next (same flow). Enter the passphrase you set in `$env:PASS`.
5. In iTAK:
   - Go to `Settings → Server Connections`.
   - Add a new connection pointing to `takserver`, port `8089`, and pick the imported identity.
   - Verify that data flows (look for green lock next to the connection).

If you need HTTPS access to WebTAK from the phone’s browser, load the CA profile system-wide and browse to `https://takserver:9443/Marti/`.

---

## 3. Meshtastic + TAK bridge

Use the same `makeCert.sh client` flow, then copy these files to the Meshtastic host (Raspberry Pi, Docker host, etc.):

- `DEVICE_NAME.pem` (client cert)
- `DEVICE_NAME.key` (private key)
- `ca.pem` (Vivarium CA)

Convert to the formats Meshtastic expects if necessary:

```bash
openssl pkcs12 -in DEVICE_NAME.p12 -clcerts -nokeys -out DEVICE_NAME.pem
openssl pkcs12 -in DEVICE_NAME.p12 -nocerts -out DEVICE_NAME.key
```

Update your Meshtastic bridge configuration (example in `meshtastic-tak.conf.example`):

```
[tak]
host = takserver
port = 8089
cot_port = 8999
ca_cert = /opt/meshtastic/certs/ca.pem
client_cert = /opt/meshtastic/certs/DEVICE_NAME.pem
client_key = /opt/meshtastic/certs/DEVICE_NAME.key
```

Restart the Meshtastic bridge service so it picks up the new credentials.

---

## 4. Quick checklist

- [ ] The new `.p12` and `.pem` live in `official-tak/offline-transfer/tak-certs` for backup.
- [ ] `UserManager.jar certmod` ran for every new cert (ROLE_OPERATOR or ROLE_ADMIN as needed).
- [ ] iOS devices have both the Vivarium CA and the device identity installed.
- [ ] Meshtastic configs reference the correct CA/cert/key paths and point to `takserver:8089`.
- [ ] The hosts file on each client includes `127.0.0.1 takserver` (or the LAN IP if remote).
