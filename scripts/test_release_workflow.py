#!/usr/bin/env python3
"""Release-hygiene tests for the pi-gen workflow."""

import pathlib
import unittest


ROOT = pathlib.Path(__file__).resolve().parent.parent


class ReleaseWorkflowTestCase(unittest.TestCase):
    def test_semver_prerelease_tag_is_published_as_prerelease(self):
        workflow = (ROOT / ".github/workflows/pi-gen.yml").read_text()

        self.assertIn('[[ "$TAG" =~ ^v[0-9]+[.][0-9]+[.][0-9]+- ]]', workflow)
        self.assertIn("args+=(--prerelease)", workflow)


if __name__ == "__main__":
    unittest.main()
