# Server certificates

## Description
Server certificates authenticate servers in TLS, containing public keys and domain info.

## Features
- **SAN**: Multiple domains.
- **EV/OV**: Validation levels.
- **Key Exchange**: RSA/ECDSA.
- **Validity**: 1-2 years.
- **Auto-Renew**: Let's Encrypt style.
- **Usage**: HTTPS, etc.

## Relevance to Current Build
For securing services like HA, TAK.

## Related Components
- [[TLS]]: Used in.
- [[Intermediate CA]]: Issuer.
- [[MQTT over TLS]]: Application.
