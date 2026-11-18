"""Build a manual-install ZIP containing only the runtime and documentation."""
import argparse
from pathlib import Path
import sys
from zipfile import ZIP_DEFLATED, ZipFile

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from tools.project_version import bump_build, read_metadata, validate_generated

ROOT = Path(__file__).resolve().parents[1]


def package(output: Path | None = None) -> Path:
    validate_generated()
    version, build = read_metadata()
    output = output or ROOT / "dist" / f"perfREV-{version}-build{build}.zip"
    files = ["perfREV.lua", "lib/perfrev_core.lua", "lib/perfrev_version.lua", "README.md", "LICENSE"]
    for name in files:
        if not (ROOT / name).is_file():
            raise FileNotFoundError(name)
    output.parent.mkdir(parents=True, exist_ok=True)
    with ZipFile(output, "w", ZIP_DEFLATED) as archive:
        for name in files:
            archive.write(ROOT / name, "perfREV/" + name)
    return output


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--new-build", action="store_true", help="Increment build and sync metadata before packaging")
    args = parser.parse_args()
    if args.new_build:
        bump_build()
    print(package())
