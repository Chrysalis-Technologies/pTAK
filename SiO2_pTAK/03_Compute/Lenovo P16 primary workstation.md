# Lenovo P16 (primary workstation)

## Description
The Lenovo ThinkPad P16 is a high-performance mobile workstation laptop designed for demanding tasks like AI training, virtualization, and CAD, featuring powerful CPUs, GPUs, and ample RAM/storage.

## Features
- **Hardware Specs**: Intel Core i9, NVIDIA RTX GPUs, up to 128GB RAM, 8TB SSD.
- **Display**: 16" 4K OLED or IPS with high refresh.
- **Connectivity**: Thunderbolt 4, Wi-Fi 6E, Ethernet.
- **Build Quality**: MIL-STD durability, keyboard with numpad.
- **Software**: Windows/Linux compatible, ISV certifications.
- **Expandability**: Upgradeable components.

## Relevance to Current Build
As the primary workstation in Compute/Virtualization Layer, it hosts Windows 11, WSL, Docker, and runs local LLMs, serving as the dev hub for the entire system.

## Related Components
- [[Windows 11]]: OS running on P16.
- [[WSL]]: Linux subsystem for dev.
- [[Docker]]: Containerization on P16.
- [[Docker Compose]]: Multi-container orchestration.
- [[Hypervisor-based VM hosting]]: Via built-in Hyper-V.
- [[03_Compute/Proxmox planned|Proxmox (planned)]]: Future virtualization expansion.
- [[01_AI/Local LLMs DeepSeek, Qwen, Nous Hermes, Dolphin|Local LLMs (DeepSeek, Qwen, Nous Hermes, Dolphin)]]: Runs on P16 GPU.
