# QGIS to TAK Overlays

This repo treats QGIS/PostGIS as the authoritative map source. Publish overlays to WinTAK using KML exports or a simple HTTP KML endpoint.

## KML export workflow
1. In QGIS, organize layers into named groups (Zones, Assets, Hazards).
2. Use "Save As" -> KML for each group or a combined KML.
3. Store exported KML under a folder you can serve (see optional `kml-publisher` service).

## KML network link (WinTAK)
1. In WinTAK, add a new KML Network Link.
2. Point it at `http://<host>:7070/overlays/farm.kml` (or your own URL).
3. Set refresh to 30-120 seconds depending on expected change rate.

## Naming and refresh guidance
- Use stable names so WinTAK updates the same overlay instead of duplicating.
- Prefer one overlay per operational layer (zones, assets, hazards).
- For large layers, split by zone to keep KML payload sizes manageable.

## Optional KML publisher
- If you enable the `kml-publisher` service, it serves `./overlays/` over HTTP at port 7070.
- Place `farm.kml` under `overlays/` and point WinTAK to the network link URL.