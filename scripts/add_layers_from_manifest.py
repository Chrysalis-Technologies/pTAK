import os, sys, argparse
from pathlib import Path
from qgis.core import (
    QgsApplication, QgsProject, QgsRasterLayer, QgsVectorLayer,
    QgsLayerTreeGroup, QgsCoordinateReferenceSystem
)
try:
    import yaml
except ImportError:
    print("PyYAML missing inside QGIS Python. Run: python -m pip install PyYAML", file=sys.stderr)
    sys.exit(1)

def ensure_group(root, name: str):
    g = root.findGroup(name)
    return g if g else root.addGroup(name)

def add_xyz(name, url, zmin=0, zmax=19):
    # XYZ via WMS provider with xyz params
    uri = f"type=xyz&url={url}&zmin={int(zmin)}&zmax={int(zmax)}"
    rl = QgsRasterLayer(uri, name, "wms")
    if not rl.isValid():
        raise RuntimeError(f"Failed XYZ: {name}")
    return rl

def add_vector_file(name, path):
    vl = QgsVectorLayer(path, name, "ogr")
    if not vl.isValid():
        raise RuntimeError(f"Failed vector: {path}")
    return vl

def add_wms(name, url, layers, styles="", crs="EPSG:3857", fmt="image/png", dpiMode=7):
    params = (
        f"url={url}&layers={layers}&styles={styles}"
        f"&crs={crs}&format={fmt}&dpiMode={dpiMode}&featureCount=10"
        "&contextualWMSLegend=0&tileMatrixSet=GoogleMapsCompatible"
    )
    rl = QgsRasterLayer(params, name, "wms")
    if not rl.isValid():
        raise RuntimeError(f"Failed WMS: {name}")
    return rl

def add_wfs(name, url, typename, version="2.0.0"):
    uri = f"url='{url}' typename='{typename}' version='{version}'"
    vl = QgsVectorLayer(uri, name, "WFS")
    if not vl.isValid():
        raise RuntimeError(f"Failed WFS: {name}")
    return vl

def main(manifest_path: Path):
    cfg = yaml.safe_load(manifest_path.read_text(encoding="utf-8"))
    project_path = Path(cfg["project"])
    layers_cfg = cfg.get("layers", [])
    groups_cfg = cfg.get("groups", [])

    app = QgsApplication([], False)
    app.initQgis()
    try:
        proj = QgsProject.instance()
        if project_path.exists():
            if not proj.read(str(project_path)):
                raise RuntimeError(f"Open project failed: {project_path}")
        else:
            proj.setCrs(QgsCoordinateReferenceSystem("EPSG:3857"))

        root = proj.layerTreeRoot()
        for g in groups_cfg:
            ensure_group(root, g["name"])

        added = []
        for item in layers_cfg:
            ltype = item["type"].lower()
            name  = item["name"]
            group = item.get("group")

            existing = [lyr for lyr in proj.mapLayers().values() if lyr.name() == name]
            if existing:
                print(f"Skipping existing layer: {name}")
                continue

            if ltype == "xyz":
                lyr = add_xyz(name, item["url"], item.get("zmin",0), item.get("zmax",19))
            elif ltype == "vector_file":
                lyr = add_vector_file(name, item["path"])
            elif ltype == "wms":
                lyr = add_wms(name, item["url"], item["layers"], item.get("styles",""),
                              item.get("crs","EPSG:3857"), item.get("format","image/png"),
                              item.get("dpiMode",7))
            elif ltype == "wfs":
                lyr = add_wfs(name, item["url"], item["typename"], item.get("version","2.0.0"))
            else:
                raise RuntimeError(f"Unknown layer type: {ltype}")

            if not proj.addMapLayer(lyr, False):
                raise RuntimeError(f"Add to project failed: {name}")

            if group:
                grp = ensure_group(root, group)
                grp.addLayer(lyr)
            else:
                root.addLayer(lyr)
            added.append(name)

        if not proj.write(str(project_path)):
            raise RuntimeError(f"Save project failed: {project_path}")

        print("Added layers:")
        for n in added: print(f" - {n}")
        print(f"Updated project: {project_path}")
    finally:
        app.exitQgis()

if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--manifest", required=True)
    args = ap.parse_args()
    main(Path(args.manifest))
