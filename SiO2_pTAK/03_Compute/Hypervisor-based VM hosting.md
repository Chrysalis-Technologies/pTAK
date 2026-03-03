# Hypervisor-based VM hosting

## Description
Hypervisor-based VM hosting uses software like Hyper-V or KVM to create and manage virtual machines, emulating hardware for running multiple OSes on one physical host.

## Features
- **Isolation**: Secure VM separation.
- **Resource Allocation**: CPU, RAM, disk passthrough.
- **Snapshots**: State backups.
- **Migration**: Live VM moves.
- **Networking**: Virtual switches.
- **GPU Passthrough**: For AI/compute.

## Relevance to Current Build
In Compute Layer, via Hyper-V on Windows or Proxmox, hosts VMs for isolated services like HAOS or dev environments.

## Related Components
- [[03_Compute/Proxmox planned|Proxmox (planned)]]: KVM-based hypervisor.
- [[Windows 11]]: Hyper-V integration.
- [[03_Compute/Lenovo P16 primary workstation|Lenovo P16 (primary workstation)]]: Host hardware.
- [[02_Applications/Home Assistant OS HAOS|Home Assistant OS (HAOS)]]: Potential VM guest.
