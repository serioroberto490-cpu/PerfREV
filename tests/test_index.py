import importlib.util
from pathlib import Path
import tempfile
import unittest
import xml.etree.ElementTree as ET

spec = importlib.util.spec_from_file_location(
    "build_index", Path(__file__).resolve().parents[1] / "tools" / "build_index.py"
)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class IndexTests(unittest.TestCase):
    def test_sources_and_layout(self):
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / "index.xml"
            module.build("https://example.org/perfREV/v0.1.0", target)
            root = ET.parse(target).getroot()
            self.assertEqual(root.attrib["version"], "1")
            package = root.find("./category/reapack")
            self.assertEqual(package.attrib["type"], "script")
            sources = package.findall("./version/source")
            self.assertEqual(len(sources), 5)
            self.assertEqual(sources[0].attrib["main"], "main")
            self.assertEqual(sources[0].attrib["file"], "perfREV.lua")
            self.assertNotIn("main", sources[1].attrib)
            self.assertEqual(sources[1].attrib["file"], "lib/perfrev_core.lua")
            self.assertEqual(
                sources[1].text,
                "https://example.org/perfREV/v0.1.0/lib/perfrev_core.lua",
            )
            self.assertEqual(sources[2].attrib["file"], "lib/perfrev_version.lua")
            self.assertEqual(sources[3].attrib["file"], "lib/perfrev_reverb.lua")
            self.assertEqual(sources[4].attrib["file"], "lib/perfrev_theme.lua")
            release, build = module.read_metadata()
            self.assertEqual(package.find("./version").attrib["name"], release)
            self.assertEqual(package.find("./version/changelog").text, f"Build {build}")

    def test_reject_invalid_urls(self):
        for url in ["file:///local", "http://example.org", "https://", "https://host/?q=1", "https://host/#a"]:
            with self.subTest(url=url), self.assertRaises(ValueError):
                module.build(url, Path("unused.xml"))

    def test_preserves_historical_version_and_pinned_sources(self):
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / "index.xml"
            module.build("https://example.org/current", target)
            tree = ET.parse(target)
            package = tree.getroot().find("./category/reapack")
            old = ET.SubElement(package, "version", {"name": "0.0.1"})
            ET.SubElement(old, "source", {"main": "main"}).text = "https://example.org/immutable/script.lua"
            tree.write(target, encoding="utf-8")
            module.build("https://example.org/current", target)
            package = ET.parse(target).getroot().find("./category/reapack")
            self.assertEqual(len(package.findall("version")), 2)
            self.assertEqual(
                package.find("./version[@name='0.0.1']/source").text,
                "https://example.org/immutable/script.lua",
            )


if __name__ == "__main__":
    unittest.main()
