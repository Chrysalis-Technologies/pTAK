# Offline Transfer Artifacts

This folder holds sensitive runtime data (certificates, takdata, etc.) that stay untracked.
Copy the subfolders to removable media and drop them on another host after cloning the repo.
Do **not** commit anything inside this directory.

## Contents

- `takdata-runtime/`  – the live `/opt/tak/data` volume from a running stack.
- `takdata-bundle/`   – the `takdata` directory that ships with the docker bundle (seed data).
- `tak-certs/`        – the files copied from `/opt/tak/certs/files` (CA, server, client certs).

## Rehydrate after cloning

Run the helper script from the repo root to copy the snapshots back into place:

```powershell
pwsh scripts/rehydrate-official-tak.ps1           # default source = official-tak/offline-transfer
pwsh scripts/rehydrate-official-tak.ps1 -Force    # overwrite existing takdata/certs
pwsh scripts/rehydrate-official-tak.ps1 -SourceRoot F:\transfer\tak -Force
```

If you are rehydrating from an external drive, point `-SourceRoot` at the folder that contains
`takdata-runtime`, `takdata-bundle`, and `tak-certs`.
