from pathlib import Path
import json
import re

ROOT = Path(__file__).resolve().parent
LIMIT = 512 * 1024
packages = []
seen = set()
for path in sorted((ROOT / "packages").glob("*.juz")):
    if path.stat().st_size > LIMIT:
        raise SystemExit(f"Package too large: {path.name}")
    package = json.loads(path.read_text(encoding="utf-8"))
    manifest = package.get("manifest", {})
    app_id = manifest.get("id")
    if not isinstance(app_id, str) or not re.fullmatch(r"[a-z0-9_-]+", app_id):
        raise SystemExit(f"Invalid ID: {path.name}")
    if app_id in seen:
        raise SystemExit(f"Duplicate ID: {app_id}")
    if manifest.get("api") != 1 or not isinstance(manifest.get("name"), str):
        raise SystemExit(f"Invalid manifest: {path.name}")
    if not isinstance(manifest.get("version"), str) or not re.fullmatch(r"\d+\.\d+\.\d+", manifest["version"]):
        raise SystemExit(f"Invalid version: {path.name}")
    entry = manifest.get("entry")
    files = package.get("files")
    if not isinstance(files, dict) or entry not in files or not isinstance(files[entry], str):
        raise SystemExit(f"Invalid entry point: {path.name}")
    if not re.fullmatch(r"[A-Za-z0-9_.-]+\.juz", path.name):
        raise SystemExit(f"Invalid package filename: {path.name}")
    item = dict(manifest)
    item["package"] = "packages/" + path.name
    packages.append(item)
    seen.add(app_id)
document = {"format": 1, "packages": packages}
(ROOT / "index.json").write_text(json.dumps(document, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(f"Updated index.json: {len(packages)} package(s)")
