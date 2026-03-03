# Docker

## Description
Docker is a platform for developing, shipping, and running applications in containers, which package code and dependencies for consistent execution across environments.

## Features
- **Containerization**: Isolated, lightweight environments.
- **Images**: Build from Dockerfiles, share via registries.
- **Networking**: Custom networks, ports.
- **Volumes**: Persistent data storage.
- **CLI/API**: docker run, build, etc.
- **Security**: Namespaces, seccomp.

## Relevance to Current Build
Core to Compute Layer for hosting apps like TAK Server, Home Assistant, and Frigate on P16 or Proxmox.

## Related Components
- [[Docker Compose]]: Multi-container management.
- [[02_Applications/TAK Server Docker|TAK Server (Docker)]]: Specific container.
- [[Home Assistant Core]]: Docker install option.
- [[Frigate]]: Docker-based NVR.
- [[Paperless-ngx]]: Docker deployment.
- [[Docker volumes]]: Storage integration.
- [[03_Compute/Proxmox planned|Proxmox (planned)]]: Hosts Docker.
