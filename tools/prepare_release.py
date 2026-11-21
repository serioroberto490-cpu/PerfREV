"""Archive an existing authorized ZIP with checksum and manifest. Never builds or publishes."""
import argparse
import hashlib
import json
from pathlib import Path
import sys
from zipfile import ZipFile

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from tools.project_version import PATTERN

ROOT = Path(__file__).resolve().parents[1]


def prepare(source: Path, archive_root: Path | None = None) -> Path:
    source = source.resolve(strict=True)
    if source.suffix.lower() != ".zip":
        raise ValueError("Expected an existing ZIP; this tool does not build packages")
    data = source.read_bytes()
    with ZipFile(source) as package:
        if package.testzip() is not None:
            raise ValueError("Corrupted ZIP")
        metadata = package.read("perfREV/lib/perfrev_version.lua").decode("utf-8")
    match = PATTERN.fullmatch(metadata)
    if not match:
        raise ValueError("Invalid package version metadata")
    version, build = match[1], int(match[2])
    name = f"perfREV-{version}-build{build}.zip"
    digest = hashlib.sha256(data).hexdigest()
    directory = (archive_root or ROOT / "dist" / "releases") / f"v{version}"
    manifest = {
        "version": version, "build": build, "source_commit": None,
        "artifacts": [{"file": name, "sha256": digest, "size_bytes": len(data)}],
    }
    expected = {
        directory / name: data,
        directory / (name + ".sha256"): f"{digest}  {name}\n".encode("utf-8"),
        directory / "release.json": (json.dumps(manifest, indent=2) + "\n").encode("utf-8"),
    }
    # Check every conflict before writing or creating anything.
    for path, content in expected.items():
        if path.exists() and path.read_bytes() != content:
            raise FileExistsError(f"Existing release differs: {path}; nothing overwritten")
    directory.mkdir(parents=True, exist_ok=True)
    for path, content in expected.items():
        if not path.exists():
            path.write_bytes(content)
    return directory


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("package", type=Path)
    args = parser.parse_args()
    try:
        print(prepare(args.package))
    except (OSError, ValueError, KeyError) as exc:
        parser.error(str(exc))
