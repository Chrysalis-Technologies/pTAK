# MQTT

## Description
Message Queuing Telemetry Transport (MQTT) is a lightweight pub/sub protocol for IoT, enabling efficient, reliable messaging over unreliable networks.

## Features
- **Pub/Sub**: Topics for decoupling.
- **QoS Levels**: 0-2 for delivery guarantees.
- **Retain**: Last message storage.
- **Will Messages**: Offline notifications.
- **Sessions**: Persistent connections.
- **Brokers**: Central or distributed.

## Relevance to Current Build
Primary transport in Messaging Layer for sensors to hub.

## Related Components
- [[MQTT integration]]: HA.
- [[MQTT over TLS]]: Secure.
- [[Meshtastic nodes]]: Gateway.
- [[Frigate]]: Events.
