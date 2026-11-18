from pathlib import Path
import shutil
import tempfile
import unittest

from tools import project_version as versioning


class VersionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / "lib").mkdir()
        for filename in ["lib/perfrev_version.lua", "perfREV.lua", "README.md"]:
            shutil.copy2(versioning.ROOT / filename, self.root / filename)

    def test_current_generated_fields(self):
        version, build = versioning.read_metadata(self.root)
        self.assertRegex(version, r"^\d+\.\d+\.\d+$")
        self.assertGreaterEqual(build, 1)
        versioning.validate_generated(self.root)

    def test_increment_build_and_update_generated_fields(self):
        current, build = versioning.read_metadata(self.root)
        self.assertEqual(versioning.bump_build(self.root), (current, build + 1))
        versioning.validate_generated(self.root)
        self.assertIn(f"build **{build + 1}**", (self.root / "README.md").read_text(encoding="utf-8"))

    def test_set_version_also_increments_build(self):
        _, build = versioning.read_metadata(self.root)
        self.assertEqual(versioning.bump_build(self.root, "2.3.4"), ("2.3.4", build + 1))
        source = (self.root / "perfREV.lua").read_text(encoding="utf-8")
        self.assertIn("-- @version 2.3.4\n", source)
        versioning.validate_generated(self.root)

    def test_sync_does_not_increment(self):
        original = versioning.read_metadata(self.root)
        versioning.sync_generated(self.root)
        self.assertEqual(versioning.read_metadata(self.root), original)

    def test_invalid_version_does_not_modify_metadata(self):
        original = (self.root / versioning.METADATA).read_bytes()
        for value in ["1.2", "01.2.3", "1.2.3-alpha", "-1.2.3", "1.2.3.4"]:
            with self.subTest(value=value), self.assertRaises(ValueError):
                versioning.bump_build(self.root, value)
        self.assertEqual((self.root / versioning.METADATA).read_bytes(), original)

    def test_stale_generated_header_rejected(self):
        source = self.root / "perfREV.lua"
        source.write_text(
            source.read_text(encoding="utf-8").replace("-- @version ", "-- @version 99.", 1),
            encoding="utf-8",
        )
        with self.assertRaises(ValueError):
            versioning.validate_generated(self.root)
        versioning.sync_generated(self.root)
        versioning.validate_generated(self.root)

    def test_invalid_metadata_rejected(self):
        for content in ['return { version = "1.2", build = 1 }', 'return { version = "1.2.3", build = 0 }']:
            (self.root / versioning.METADATA).write_text(content, encoding="utf-8")
            with self.subTest(content=content), self.assertRaises(ValueError):
                versioning.read_metadata(self.root)
