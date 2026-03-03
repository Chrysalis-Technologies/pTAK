# Home Assistant Core

## Description
Home Assistant Core is the open-source software platform for home automation, allowing control of smart devices, automations, and integrations via a web dashboard.

## Features
- **Integrations**: 2000+ for devices/protocols.
- **Automations**: YAML or UI-based triggers/actions.
- **Entities**: Unified representation of devices.
- **Dashboards**: Lovelace UI customization.
- **API**: REST/WebSocket for external control.
- **Logging**: Event tracking.

## Relevance to Current Build
Core of Hub Layer, running in Docker or HAOS, coordinating sensors, cameras, and field systems via MQTT/WebSockets.

## Related Components
- [[02_Applications/Home Assistant OS HAOS|Home Assistant OS (HAOS)]]: OS for Core.
- [[HACS]]: Extends integrations.
- [[MQTT integration]]: Key protocol.
- [[WebSocket server]]: Real-time comms.
- [[Frigate]]: NVR integration.
- [[BookStack]]: Potential knowledge base link.
- [[Paperless-ngx]]: Document management tie-in.
