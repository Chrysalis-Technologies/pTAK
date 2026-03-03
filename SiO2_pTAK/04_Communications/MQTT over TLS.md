# MQTT over TLS

## Description
MQTT over TLS secures the MQTT protocol with TLS encryption, preventing eavesdropping and ensuring secure IoT messaging.

## Features
- **Encryption**: All traffic secured.
- **Auth**: Certificates for clients/broker.
- **Integrity**: Tamper detection.
- **Port**: Typically 8883.
- **Overhead**: Minimal for IoT.
- **Compatibility**: With standard MQTT.

## Relevance to Current Build
Secure variant in Messaging Layer for hub-field comms.

## Related Components
- [[MQTT]]: Base protocol.
- [[TLS]]: Security layer.
- [[Mutual TLS]]: Enhanced auth.
- [[MQTT integration]]: HA use.
