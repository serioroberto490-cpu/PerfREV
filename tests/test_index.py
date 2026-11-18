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
            self.assertEqual(len(sources), 3)
            self.assertEqual(sources[0].attrib["main"], "main")
            self.assertEqual(sources[0].attrib["file"], "perfREV.lua")
            self.assertNotIn("main", sources[1].attrib)
            self.assertEqual(sources[1].attrib["file"], "lib/perfrev_core.lua")
            self.assertEqual(
                sources[1].text,
                "https://example.org/perfREV/v0.1.0/lib/perfrev_core.lua",
            )
            self.assertEqual(sources[2].attrib["file"], "lib/perfrev_version.lua")
            release, build = module.read_metadata()
            self.assertEqual(package.find("./version").attrib["name"], release)
            self.assertEqual(package.find("./version/changelog").text, f"Build {build}")

    def test_reject_invalid_urls(self):
        for url in ["file:///local", "http://example.org", "https://", "https://host/?q=1", "https://host/#a"]:
            with self.subTest(url=url), self.assertRaises(ValueError):
                module.build(url, Path("unused.xml"))


if __name__ == "__main__":
    unittest.main()
