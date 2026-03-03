# Proxmox (planned)

## Description
Proxmox VE is an open-source virtualization platform based on Debian, combining KVM hypervisor, LXC containers, and storage/network management for building private clouds or homelabs.

## Features
- **Virtualization**: VMs (KVM/QEMU) and containers (LXC).
- **Clustering**: High availability with multiple nodes.
- **Storage**: ZFS, Ceph, NFS support.
- **Backup/Restore**: Integrated snapshots and replication.
- **Web UI**: Management dashboard.
- **Networking**: SDN, VLANs, firewalls.

## Relevance to Current Build
Planned for Compute/Virtualization Layer to scale beyond P16, hosting VMs for Home Assistant, TAK Server, and Docker containers.

## Related Components
- [[03_Compute/Lenovo P16 primary workstation|Lenovo P16 (primary workstation)]]: Initial host, transition to Proxmox.
- [[Hypervisor-based VM hosting]]: Proxmox as the hypervisor.
- [[Docker]]: Containers within Proxmox LXC.
- [[Docker Compose]]: For apps like TAK Server.
- [[02_Applications/Home Assistant OS HAOS|Home Assistant OS (HAOS)]]: Potential VM guest.
- [[02_Applications/TAK Server Docker|TAK Server (Docker)]]: Hosted container.
