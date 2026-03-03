# UDP

## Description
User Datagram Protocol (UDP) is a connectionless transport protocol for low-latency, lightweight data transmission without reliability guarantees.

## Features
- **Simplicity**: No handshakes.
- **Multicast/Broadcast**: Group sending.
- **Low Overhead**: Small headers.
- **Applications**: DNS, video streaming.
- **Ports**: Multiplexing.
- **Checksums**: Basic error detection.

## Relevance to Current Build
Used in Messaging for CoT, real-time sensor data.

## Related Components
- [[TCP/IP]]: Suite.
- [[04_Communications/CoT Cursor on Target|CoT (Cursor on Target)]]: Often over UDP.
- [[MQTT]]: TCP alternative.
