# Internal CA

## Description
An Internal Certificate Authority (CA) is a private PKI for issuing certificates within an organization, managing trust for internal services.

## Features
- **Issuance**: Certs for servers/clients.
- **Hierarchy**: Root/Intermediate.
- **Revocation**: CRL/OCSP.
- **Tools**: OpenSSL, EJBCA.
- **Automation**: ACME-like.
- **Security**: HSM for keys.

## Relevance to Current Build
Base for PKI in Security Layer, issuing certs for TLS.

## Related Components
- [[Root CA]]: Top level.
- [[Intermediate CA]]: Chained.
- [[Client certificates]]: Issued.
- [[Server certificates]]: Issued.
- [[CRL]]: Revocation.
