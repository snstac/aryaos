#!/usr/bin/env python3
"""Regression tests for the public AryaOS documentation theme."""

from pathlib import Path
import unittest

import yaml


ROOT = Path(__file__).resolve().parents[1]


class DocsThemeTestCase(unittest.TestCase):
    def test_light_palette_is_the_unconditional_default(self):
        # The later Markdown extension section intentionally contains MkDocs
        # Python object tags. Keep this configuration assertion safe and
        # dependency-light by parsing only the ordinary YAML before `nav:`.
        source = (ROOT / "mkdocs.yml").read_text()
        config = yaml.safe_load(source.split("\nnav:", 1)[0])
        palette = config["theme"]["palette"]

        self.assertEqual("default", palette[0]["scheme"])
        self.assertNotIn("media", palette[0])
        self.assertEqual("Switch to dark mode", palette[0]["toggle"]["name"])

        self.assertEqual("slate", palette[1]["scheme"])
        self.assertNotIn("media", palette[1])
        self.assertEqual("Switch to light mode", palette[1]["toggle"]["name"])


if __name__ == "__main__":
    unittest.main()
