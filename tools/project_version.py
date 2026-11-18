"""Single-source release metadata and generated display metadata.

The authoritative file is lib/perfrev_version.lua, read directly by REAPER.
The ReaScript @version header and README version block are generated copies.
No Git commands, tags, releases, or network operations are performed.
"""
import argparse
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
METADATA = Path("lib/perfrev_version.lua")
SEMVER = r"(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)"
PATTERN = re.compile(
    r'\s*(?:--[^\n]*\n)*return\s*\{\s*version\s*=\s*"('
    + SEMVER
    + r')"\s*,\s*build\s*=\s*([1-9][0-9]*)\s*\}\s*'
)
START = "<!-- perfREV:version:start -->"
END = "<!-- perfREV:version:end -->"


def read_metadata(root: Path = ROOT) -> tuple[str, int]:
    text = (root / METADATA).read_text(encoding="utf-8")
    match = PATTERN.fullmatch(text)
    if not match:
        raise ValueError("Invalid version metadata: use MAJOR.MINOR.PATCH and a positive integer build")
    return match[1], int(match[2])


def expected_files(root: Path = ROOT) -> dict[Path, str]:
    version, build = read_metadata(root)
    script = root / "perfREV.lua"
    source = script.read_text(encoding="utf-8")
    source, replacements = re.subn(r"(?m)^-- @version .+$", "-- @version " + version, source)
    if replacements != 1:
        raise ValueError("Expected exactly one generated ReaScript @version header")
    readme = root / "README.md"
    doc = readme.read_text(encoding="utf-8")
    block = (
        START + f"\nVersione corrente: **{version}**, build **{build}**.\n"
        f"Pacchetto corrente: `dist/perfREV-{version}-build{build}.zip`.\n" + END
    )
    doc, replacements = re.subn(re.escape(START) + r".*?" + re.escape(END), block, doc, flags=re.S)
    if replacements != 1:
        raise ValueError("README must contain exactly one generated version block")
    return {script: source, readme: doc}


def sync_generated(root: Path = ROOT) -> None:
    for path, content in expected_files(root).items():
        if path.read_text(encoding="utf-8") != content:
            path.write_text(content, encoding="utf-8")


def validate_generated(root: Path = ROOT) -> None:
    for path, expected in expected_files(root).items():
        if path.read_text(encoding="utf-8") != expected:
            raise ValueError(f"{path.name} is out of sync: run python tools/project_version.py --sync")


def bump_build(root: Path = ROOT, version: str | None = None) -> tuple[str, int]:
    current, build = read_metadata(root)
    new_version = version if version is not None else current
    if not re.fullmatch(SEMVER, new_version):
        raise ValueError("Version must use MAJOR.MINOR.PATCH, without leading zeros")
    # Validate structure before changing any metadata.
    expected_files(root)
    (root / METADATA).write_text(
        "-- Official perfREV release metadata. Edit with tools/project_version.py.\n"
        f'return {{ version = "{new_version}", build = {build + 1} }}\n',
        encoding="utf-8",
    )
    sync_generated(root)
    return new_version, build + 1


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    actions = parser.add_mutually_exclusive_group()
    actions.add_argument("--sync", action="store_true", help="Refresh generated metadata, without incrementing build")
    actions.add_argument("--check", action="store_true", help="Check metadata and generated fields")
    actions.add_argument("--bump-build", action="store_true", help="Increment build, retain current version")
    actions.add_argument("--set-version", help="Set MAJOR.MINOR.PATCH and increment build")
    args = parser.parse_args()
    try:
        if args.bump_build or args.set_version is not None:
            bump_build(version=args.set_version)
        elif args.sync:
            sync_generated()
        else:
            validate_generated()
        version, build = read_metadata()
    except (ValueError, OSError) as exc:
        parser.error(str(exc))
    print(f"perfREV {version} | build {build}")
