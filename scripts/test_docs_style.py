#!/usr/bin/env python3
"""Style checks for published documentation and the repository README."""

from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[1]


class DocsStyleTestCase(unittest.TestCase):
    def setUp(self):
        self.docs = [ROOT / "README.md", *sorted((ROOT / "docs").rglob("*.md"))]

    def test_docs_use_plain_ascii_punctuation(self):
        forbidden = {
            "\N{EM DASH}": "em dash",
            "\N{EN DASH}": "en dash",
            "\N{HORIZONTAL ELLIPSIS}": "ellipsis",
            "\N{RIGHT SINGLE QUOTATION MARK}": "curly apostrophe",
            "\N{RIGHTWARDS ARROW}": "right arrow",
            "\N{MULTIPLICATION SIGN}": "multiplication sign",
        }
        failures = []
        for path in self.docs:
            source = path.read_text()
            for character, name in forbidden.items():
                if character in source:
                    failures.append(f"{path.relative_to(ROOT)}: {name}")
        self.assertEqual([], failures)

    def test_docs_avoid_canned_marketing_phrases(self):
        pattern = re.compile(
            r"\b(?:at a glance|out of the box|simply|seamless(?:ly)?|"
            r"revolutionary|next-generation|empowering|actionable insights?|"
            r"exciting possibilities|delve|robust|comprehensive|leverage|"
            r"in this guide|important to note|worth noting|that's it|"
            r"what you'll see|everything you need)\b",
            re.IGNORECASE,
        )
        failures = []
        for path in self.docs:
            for number, line in enumerate(path.read_text().splitlines(), 1):
                if pattern.search(line):
                    failures.append(f"{path.relative_to(ROOT)}:{number}: {line.strip()}")
        self.assertEqual([], failures)


if __name__ == "__main__":
    unittest.main()
