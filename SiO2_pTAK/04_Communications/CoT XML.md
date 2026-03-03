# CoT XML

## Description
CoT XML is the XML format for Cursor on Target messages, structuring tactical data like positions and events.

## Features
- **Elements**: Point, event, detail.
- **Attributes**: UID, time, type.
- **Extensions**: Custom namespaces.
- **Validation**: Schemas.
- **Parsing**: XML libraries.
- **Compression**: For efficiency.

## Relevance to Current Build
Format in Messaging for TAK/CoT.

## Related Components
- [[04_Communications/CoT Cursor on Target|CoT (Cursor on Target)]]: Protocol.
- [[XML]]: Base (wait, CoT is XML).
- [[02_Applications/TAK Server Docker|TAK Server (Docker)]]: Handler.
