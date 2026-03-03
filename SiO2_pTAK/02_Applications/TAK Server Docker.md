# TAK Server (Docker)

## Description
TAK Server is the backend for TAK clients, handling data synchronization, user management, and integrations in a Docker-containerized form for easy deployment.

## Features
- **Data Sync**: Real-time CoT sharing.
- **Auth**: Users, groups, certs.
- **Plugins**: Mesh, video.
- **Database**: PostgreSQL backend.
- **API**: REST for external data.
- **Security**: TLS, mTLS.

## Relevance to Current Build
Dockerized in Tactical Layer, connects field devices via CoT, integrating with MQTT.

## Related Components
- [[02_Applications/TAK WinTAK - iTAK - ATAK|TAK (WinTAK / iTAK / ATAK)]]: Clients.
- [[04_Communications/CoT Cursor on Target|CoT (Cursor on Target)]]: Messaging.
- [[Docker]]: Container.
- [[MQTT]]: Bridge for IoT.
- [[Mutual TLS]]: Security.
