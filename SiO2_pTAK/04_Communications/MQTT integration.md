# MQTT integration

## Description
MQTT integration in Home Assistant enables communication with IoT devices using the MQTT protocol, allowing publish/subscribe messaging for sensors and automations.

## Features
- **Broker Support**: Built-in or external like Mosquitto.
- **Discovery**: Auto-config via MQTT Discovery.
- **Entities**: Sensors, switches, etc., via topics.
- **Security**: TLS, authentication.
- **Retain/QoS**: Message persistence/reliability.
- **Custom Topics**: Flexible pub/sub.

## Relevance to Current Build
Central to Hub Layer for connecting edge devices, field systems, and radios via MQTT over TLS.

## Related Components
- [[Home Assistant Core]]: Integration host.
- [[MQTT]]: Protocol itself.
- [[MQTT over TLS]]: Secure variant.
- [[Meshtastic nodes]]: MQTT gateway.
- [[Zigbee sensors]]: Via MQTT bridge.
- [[BLE sensors]]: MQTT forwarding.
- [[Frigate]]: Event publishing.
