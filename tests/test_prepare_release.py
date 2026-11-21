import hashlib
import json
from pathlib import Path
import tempfile
import unittest

from tools.package import package
from tools.prepare_release import prepare
from tools.project_version import read_metadata


class PrepareReleaseTests(unittest.TestCase):
    def test_checksum_manifest_and_idempotence(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = package(root / "input.zip")
            folder = prepare(source, root / "archive")
            version, build = read_metadata()
            name = f"perfREV-{version}-build{build}.zip"
            manifest = json.loads((folder / "release.json").read_text())
            self.assertEqual(manifest["version"], version)
            self.assertEqual(manifest["build"], build)
            self.assertIsNone(manifest["source_commit"])
            digest = hashlib.sha256(source.read_bytes()).hexdigest()
            self.assertEqual(manifest["artifacts"][0]["sha256"], digest)
            self.assertEqual((folder / (name + ".sha256")).read_text(), f"{digest}  {name}\n")
            before = {f.name: f.read_bytes() for f in folder.iterdir()}
            self.assertEqual(prepare(source, root / "archive"), folder)
            self.assertEqual(before, {f.name: f.read_bytes() for f in folder.iterdir()})

    def test_conflict_preserves_all_files(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = package(root / "input.zip")
            folder = prepare(source, root / "archive")
            manifest = folder / "release.json"
            manifest.write_text('{"source_commit": "verified-do-not-replace"}')
            before = {f.name: f.read_bytes() for f in folder.iterdir()}
            with self.assertRaises(FileExistsError):
                prepare(source, root / "archive")
            self.assertEqual(before, {f.name: f.read_bytes() for f in folder.iterdir()})
