# Intermediate CA

## Description
Intermediate CA is a subordinate CA signed by the root, used for issuing end-entity certs to limit root exposure.

## Features
- **Chaining**: Path to root.
- **Shorter Validity**: Months/years.
- **Specialization**: Per dept/use.
- **Online**: For issuance.
- **Revocation**: Easier than root.
- **Policies**: Constraints.

## Relevance to Current Build
Handles day-to-day cert issuance in PKI.

## Related Components
- [[Root CA]]: Signs intermediate.
- [[Client certificates]]: Issued.
- [[Server certificates]]: Issued.
- [[CRL]]: For revocations.
