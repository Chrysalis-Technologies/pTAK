# CRL

## Description
Certificate Revocation List (CRL) is a signed list of revoked cert serial numbers, checked by clients to invalidate certs.

## Features
- **Distribution**: HTTP points.
- **Delta CRLs**: Updates only.
- **Validity**: Next update time.
- **Signing**: By CA.
- **Alternatives**: OCSP.
- **Caching**: Client-side.

## Relevance to Current Build
Revocation mechanism in PKI.

## Related Components
- [[Internal CA]]: Publisher.
- [[Root CA]]: For root.
- [[Intermediate CA]]: For intermediates.
