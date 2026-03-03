# Home Assistant OS (HAOS)

## Description
Home Assistant OS is a dedicated operating system for running Home Assistant, optimized for IoT home automation with minimal overhead, installed on hardware like Raspberry Pi or VMs.

## Features
- **Pre-Configured**: HA Core + Supervisor for add-ons.
- **Backup/Restore**: Full system snapshots.
- **Hardware Support**: Broad device compatibility.
- **Updates**: OTA for OS and HA.
- **CLI Access**: hassos-cli for management.
- **Security**: Isolated environment.

## Relevance to Current Build
Base for Hub Layer on dedicated hardware or VM, integrating sensors, cameras, and MQTT for home automation.

## Related Components
- [[Home Assistant Core]]: The core software.
- [[HACS]]: Custom add-ons.
- [[MQTT integration]]: IoT messaging.
- [[Frigate]]: Camera integration.
- [[Double-Take]]: Face rec add-on.
- [[Zigbee sensors]]: Device support.
- [[Tapo cameras]]: Integrated via HA.
