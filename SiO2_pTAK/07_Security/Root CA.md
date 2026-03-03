# Root CA

## Description
Root Certificate Authority is the top-level CA in a PKI hierarchy, self-signed, and trusted by installing in trust stores.

## Features
- **Self-Signed**: No higher authority.
- **Trust Anchor**: Basis for chain.
- **Long Validity**: Years.
- **Key Protection**: Offline storage.
- **Issuance**: To intermediates.
- **Revocation**: If compromised.

## Relevance to Current Build
Foundation of internal PKI for security.

## Related Components
- [[Internal CA]]: Part of.
- [[Intermediate CA]]: Issued by root.
- [[CRL]]: Managed.
