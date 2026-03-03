# Hub Simulator Publishers

## Overview
Python simulator scripts in this folder are kept for reference.
Primary validation should use the Docker-native PowerShell wrappers.

## Primary Test Workflow
```powershell
pwsh ./scripts/hub-publish-pos.ps1 -NodeId WinTAK-Paul
pwsh ./scripts/hub-publish-env.ps1 -NodeId WinTAK-Paul
```

## Routing Note
If WinTAK is on the Windows host and the hub stack runs in Docker, set this in `.env.hub`:

```text
TAK_COT_UDP_HOST=host.docker.internal
```

## Optional Python Reference Usage
```powershell
python hub/sim/publish_env.py --node-id WinTAK-Paul
python hub/sim/publish_pos.py --node-id WinTAK-Paul
```
