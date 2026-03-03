# TLS

## Description
Transport Layer Security (TLS) is a cryptographic protocol for secure communication over networks, providing privacy, integrity, and authentication.

## Features
- **Encryption**: Symmetric/asymmetric.
- **Handshakes**: Key exchange.
- **Versions**: 1.3 for modern security.
- **Certificates**: PKI-based auth.
- **Forward Secrecy**: Ephemeral keys.
- **Extensions**: SNI, ALPN.

## Relevance to Current Build
Secures all protocols in Security/Wireless Layers, like MQTT over TLS.

## Related Components
- [[Mutual TLS]]: Bidirectional.
- [[SSL]]: Predecessor.
- [[MQTT over TLS]]: Application.
- [[Client certificates]]: Auth.
- [[Server certificates]]: Auth.
