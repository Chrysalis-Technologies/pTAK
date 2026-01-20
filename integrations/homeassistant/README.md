# Home Assistant MQTT over Tailscale

This stack exposes a hardened MQTT broker over TLS on port 8883. HAOS should connect over Tailscale.

## Steps
1. Copy the broker CA to HAOS:
   - Source: `mqtt-certs/ca.crt` on this repo host.
   - Destination on HAOS: `/config/ssl/mqtt/ca.crt`.
2. Store MQTT credentials in HAOS `secrets.yaml`:
   - `mqtt_username: farm`
   - `mqtt_password: <your password>`
3. Configure MQTT integration:
   - UI: Settings -> Devices & Services -> MQTT -> Configure.
   - YAML: Use `integrations/homeassistant/mqtt-package.yaml` and set `broker` to the MagicDNS name of this host.
4. Reload automations/sensors or restart HAOS.

## Notes
- The broker listens on `8883` with TLS; port `1883` is disabled.
- Include the broker MagicDNS name in the MQTT server certificate SAN list when you generate certs.
- Consider locking Tailscale ACLs to only allow HAOS -> broker traffic.
