"""Build a ReaPack index after choosing the public hosting URL.

Example:
  python tools/build_index.py --base-url https://raw.githubusercontent.com/serioroberto490-cpu/PerfREV/main

Prefer an immutable commit for released package sources; main is a bootstrap option.
Publish index.xml at a stable URL.
No network requests are made by this tool.
"""
import argparse
from pathlib import Path
import sys
from urllib.parse import quote, urlsplit
import xml.etree.ElementTree as ET

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from tools.project_version import read_metadata, validate_generated

ROOT = Path(__file__).resolve().parents[1]


def build(base_url: str, output: Path) -> None:
    parsed = urlsplit(base_url)
    if parsed.scheme != "https" or not parsed.netloc or parsed.query or parsed.fragment:
        raise ValueError("Use an absolute HTTPS base URL without query or fragment")
    validate_generated()
    release, build_number = read_metadata()
    root = ET.Element("index", {"version": "1", "name": "perfREV"})
    category = ET.SubElement(root, "category", {"name": "Mixing"})
    package = ET.SubElement(
        category, "reapack",
        {"name": "perfREV.lua", "type": "script", "desc": "perfREV - Tempo, delay, riverbero e stanza"},
    )
    version = ET.SubElement(package, "version", {"name": release, "author": "perfREV"})
    ET.SubElement(version, "changelog").text = f"Build {build_number}"
    for name, is_main in [("perfREV.lua", True), ("lib/perfrev_core.lua", False),
                          ("lib/perfrev_version.lua", False), ("lib/perfrev_reverb.lua", False),
                          ("lib/perfrev_theme.lua", False)]:
        if not (ROOT / name).is_file():
            raise FileNotFoundError(name)
        attrs = {"file": name}
        if is_main:
            attrs["main"] = "main"
        source = ET.SubElement(version, "source", attrs)
        source.text = base_url.rstrip("/") + "/" + quote(name, safe="/")
    metadata = ET.SubElement(root, "metadata")
    ET.SubElement(metadata, "description").text = (
        "Calcolatori non distruttivi per tempo, delay, riverbero e prime riflessioni. "
        "REAPER 6+. Nessuna estensione obbligatoria. RS ecosystem"
    )
    # Preserve historical versions; do not silently drop downgrade paths.
    if output.exists():
        old_root = ET.parse(output).getroot()
        for old in old_root.findall("./category[@name='Mixing']/reapack[@name='perfREV.lua']/version"):
            if old.attrib.get("name") != release:
                package.append(old)
    ET.indent(root)
    ET.ElementTree(root).write(output, encoding="utf-8", xml_declaration=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base-url", required=True)
    parser.add_argument("--output", type=Path, default=ROOT / "index.xml")
    args = parser.parse_args()
    try:
        build(args.base_url, args.output)
    except (ValueError, FileNotFoundError) as exc:
        parser.error(str(exc))
    print(f"Created {args.output}")
