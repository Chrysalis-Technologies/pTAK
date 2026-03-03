# Mutual TLS

## Description
Mutual TLS (mTLS) requires both client and server to authenticate with certificates, enhancing security beyond server-only TLS.

## Features
- **Bidirectional Auth**: Trust both ways.
- **Zero Trust**: No passwords.
- **Renegotiation**: Dynamic.
- **Performance**: Handshake overhead.
- **Use Cases**: API, IoT.
- **Config**: In servers like Nginx.

## Relevance to Current Build
For secure comms in protocols like MQTT.

## Related Components
- [[TLS]]: Base.
- [[Client certificates]]: Client side.
- [[Server certificates]]: Server side.
- [[MQTT over TLS]]: With mTLS.
