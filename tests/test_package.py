import importlib.util
from pathlib import Path
import tempfile
import unittest
from zipfile import ZipFile

spec = importlib.util.spec_from_file_location(
    "package", Path(__file__).resolve().parents[1] / "tools" / "package.py"
)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class PackageTests(unittest.TestCase):
    def test_exact_runtime_files(self):
        with tempfile.TemporaryDirectory() as directory:
            target = module.package(Path(directory) / "release.zip")
            with ZipFile(target) as archive:
                self.assertEqual(
                    set(archive.namelist()),
                    {"perfREV/perfREV.lua", "perfREV/lib/perfrev_core.lua", "perfREV/lib/perfrev_version.lua",
                     "perfREV/README.md", "perfREV/LICENSE"},
                )
                self.assertIsNone(archive.testzip())
                self.assertIn(b"RS ecosystem", archive.read("perfREV/perfREV.lua"))
