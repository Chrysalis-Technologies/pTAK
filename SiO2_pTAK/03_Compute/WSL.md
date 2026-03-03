# WSL

## Description
Windows Subsystem for Linux (WSL) allows running Linux distributions natively on Windows, providing a Linux kernel and tools without dual-booting or VMs, ideal for cross-platform dev.

## Features
- **Distros**: Ubuntu, Debian, etc., via Microsoft Store.
- **Integration**: File sharing, GUI apps (WSL2), systemd support.
- **Performance**: WSL2 uses lightweight VM for near-native speed.
- **Networking**: Bridged or NAT modes.
- **GPU Support**: CUDA for AI tasks.
- **Updates**: Seamless Windows integration.

## Relevance to Current Build
Enables Linux-based tools on Windows 11/P16, like Bash, Python, and Docker, for dev automation and orchestration.

## Related Components
- [[Windows 11]]: Host OS.
- [[03_Compute/Lenovo P16 primary workstation|Lenovo P16 (primary workstation)]]: Hardware.
- [[Docker]]: Runs via WSL backend.
- [[Bash]]: Shell in WSL.
- [[Python]]: Installed in Linux env.
- [[Git]]: Cross-platform version control.
