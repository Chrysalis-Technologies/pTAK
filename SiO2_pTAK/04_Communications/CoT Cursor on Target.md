# CoT (Cursor on Target)

## Description
Cursor on Target (CoT) is an XML-based protocol for sharing tactical data like positions, events, and sensor info in real-time among systems.

## Features
- **XML Schema**: Structured data elements.
- **Event Types**: Positions, alerts, images.
- **Transport**: UDP, TCP, multicast.
- **Extensibility**: Custom extensions.
- **Security**: Encrypted variants.
- **Interoperability**: With TAK, WinTAK.

## Relevance to Current Build
Key messaging in Tactical Layer, linking TAK with field radios and GIS.

## Related Components
- [[02_Applications/TAK WinTAK - iTAK - ATAK|TAK (WinTAK / iTAK / ATAK)]]: Primary user.
- [[02_Applications/TAK Server Docker|TAK Server (Docker)]]: Handles CoT.
- [[CoT XML]]: Format.
- [[Meshtastic]]: Potential CoT gateway.
- [[QGIS]]: Data import.
- [[UDP]]: Transport.
