#!/usr/bin/env python3
"""Generate a ranked list of ag-zoned parcels in the West Genesee school district."""

from __future__ import annotations

import csv
import math
from pathlib import Path
import xml.etree.ElementTree as ET

KML_NS = "http://www.opengis.net/kml/2.2"
NS = {"kml": KML_NS}
PLACEMARK_TAG = f"{{{KML_NS}}}Placemark"

AG_PARCELS_PATH = Path("mission-packages/Ag_Parcels_Mission/overlays/Ag_Zoned_Parcels.kml")
CANDIDATE_PARCELS_PATH = Path("mission-packages/Ag_Parcels_Mission/overlays/Candidate_Parcels.kml")
OUTPUT_PATH = Path("temp/west_genesee_ag_parcels.csv")
HIGH_SCHOOL_ADDR = "5201 W Genesee St"


def parse_coords(raw: str | None) -> list[tuple[float, float]]:
    if not raw:
        return []
    coords: list[tuple[float, float]] = []
    for token in raw.replace("\n", " ").split():
        parts = token.split(",")
        if len(parts) < 2:
            continue
        try:
            lon = float(parts[0])
            lat = float(parts[1])
        except ValueError:
            continue
        coords.append((lon, lat))
    return coords


def polygon_centroid(coords: list[tuple[float, float]]) -> tuple[float, float]:
    if not coords:
        raise ValueError("Cannot compute centroid of empty coordinate list")
    if len(coords) == 1:
        return coords[0]
    pts = coords[:]
    if pts[0] != pts[-1]:
        pts.append(pts[0])
    twice_area = 0.0
    cx = 0.0
    cy = 0.0
    for i in range(len(pts) - 1):
        x0, y0 = pts[i]
        x1, y1 = pts[i + 1]
        cross = x0 * y1 - x1 * y0
        twice_area += cross
        cx += (x0 + x1) * cross
        cy += (y0 + y1) * cross
    if abs(twice_area) < 1e-12:
        xs = [lon for lon, _ in pts[:-1]]
        ys = [lat for _, lat in pts[:-1]]
        return sum(xs) / len(xs), sum(ys) / len(ys)
    area_factor = twice_area * 3.0
    return cx / area_factor, cy / area_factor


def geometry_centroid(elem: ET.Element) -> tuple[float, float] | None:
    for poly in elem.findall(".//kml:Polygon", NS):
        coord_elem = poly.find(".//kml:coordinates", NS)
        if coord_elem is None:
            continue
        coords = parse_coords(coord_elem.text)
        if coords:
            return polygon_centroid(coords)
    for point in elem.findall(".//kml:Point", NS):
        coord_elem = point.find("kml:coordinates", NS)
        if coord_elem is None:
            continue
        coords = parse_coords(coord_elem.text)
        if coords:
            return coords[0]
    return None


def iter_kml_placemarks(path: Path):
    context = ET.iterparse(path, events=("end",))
    for _, elem in context:
        if elem.tag != PLACEMARK_TAG:
            continue
        data: dict[str, str] = {}
        for sd in elem.findall(".//kml:SimpleData", NS):
            name = sd.attrib.get("name")
            if not name:
                continue
            data[name] = (sd.text or "").strip()
        centroid = geometry_centroid(elem)
        name = elem.findtext(f"{{{KML_NS}}}name") or ""
        yield name, data, centroid
        elem.clear()


def parse_float(value: str | None) -> float | None:
    if value is None or value == "":
        return None
    try:
        return float(value)
    except ValueError:
        return None


def haversine_miles(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    radius_km = 6371.0
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = (
        math.sin(dlat / 2) ** 2
        + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlon / 2) ** 2
    )
    c = 2 * math.asin(math.sqrt(a))
    return radius_km * c * 0.621371


def format_owner_address(data: dict[str, str]) -> str:
    parts = [
        data.get("MAIL_ADDR", ""),
        data.get("MAIL_CITY", ""),
        data.get("MAIL_STATE", ""),
        data.get("MAIL_ZIP", ""),
    ]
    return ", ".join(part for part in parts if part)


def resolve_high_school_centroid() -> tuple[float, float]:
    for _, data, centroid in iter_kml_placemarks(CANDIDATE_PARCELS_PATH):
        if data.get("PARCEL_ADDR") == HIGH_SCHOOL_ADDR and centroid:
            return centroid
    raise RuntimeError(f"Unable to find centroid for {HIGH_SCHOOL_ADDR}")


def collect_west_genesee_parcels(hs_centroid: tuple[float, float]):
    results = []
    for _, data, centroid in iter_kml_placemarks(AG_PARCELS_PATH):
        school_name = (data.get("SCHOOL_NAME") or "").strip().lower()
        if "west genesee" not in school_name:
            continue
        acres = parse_float(data.get("CALC_ACRES")) or parse_float(data.get("ACRES"))
        lon = lat = None
        distance = None
        if centroid:
            lon, lat = centroid
            if hs_centroid:
                distance = haversine_miles(lat, lon, hs_centroid[1], hs_centroid[0])
        mailing = format_owner_address(data)
        parcel_addr = data.get("PARCEL_ADDR")
        if not parcel_addr:
            street = " ".join(filter(None, [data.get("LOC_ST_NBR"), data.get("LOC_STREET")])).strip()
            parcel_addr = street or ""
        results.append(
            {
                "print_key": data.get("PRINT_KEY") or data.get("SWIS_PRINT_KEY_ID") or "",
                "sbl": data.get("SBL") or "",
                "parcel_addr": parcel_addr,
                "municipality": data.get("MUNI_NAME") or data.get("CITYTOWN_NAME") or "",
                "acres": acres,
                "distance_mi": distance,
                "owner": data.get("PRIMARY_OWNER") or "",
                "owner_address": mailing,
                "lat": lat,
                "lon": lon,
            }
        )
    return results


def main():
    hs_centroid = resolve_high_school_centroid()
    parcels = collect_west_genesee_parcels(hs_centroid)

    def sort_key(row):
        acres = row["acres"]
        distance = row["distance_mi"]
        return (
            -acres if acres is not None else float("inf"),
            distance if distance is not None else float("inf"),
        )

    parcels.sort(key=sort_key)
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    with OUTPUT_PATH.open("w", newline="", encoding="utf-8") as fp:
        writer = csv.writer(fp)
        writer.writerow(
            [
                "rank",
                "print_key",
                "sbl",
                "parcel_address",
                "municipality",
                "acres",
                "distance_to_WG_HS_mi",
                "owner",
                "owner_mailing_address",
                "centroid_lat",
                "centroid_lon",
            ]
        )
        for idx, row in enumerate(parcels, start=1):
            writer.writerow(
                [
                    idx,
                    row["print_key"],
                    row["sbl"],
                    row["parcel_addr"],
                    row["municipality"],
                    f"{row['acres']:.4f}" if row["acres"] is not None else "",
                    f"{row['distance_mi']:.2f}" if row["distance_mi"] is not None else "",
                    row["owner"],
                    row["owner_address"],
                    f"{row['lat']:.6f}" if row["lat"] is not None else "",
                    f"{row['lon']:.6f}" if row["lon"] is not None else "",
                ]
            )
    print(f"Wrote {len(parcels)} parcels to {OUTPUT_PATH}")


if __name__ == "__main__":
    main()
