#!/usr/bin/env python3
"""Regression tests for the cockpit-aryaos overlay patcher."""

from __future__ import annotations

import importlib.machinery
import importlib.util
from pathlib import Path
import unittest


ROOT = Path(__file__).parents[1]
PATCHER = ROOT / "shared_files/aryaos/patch-cockpit-aryaos-dp"
LOADER = importlib.machinery.SourceFileLoader("patch_cockpit_aryaos", str(PATCHER))
SPEC = importlib.util.spec_from_loader(LOADER.name, LOADER)
patcher = importlib.util.module_from_spec(SPEC)
LOADER.exec_module(patcher)


class CockpitPatchTestCase(unittest.TestCase):
    def test_workflow_launcher_upgrade_is_idempotent(self):
        old = '''<main class="aos-main">
    <section class="aos-safebanner" id="safe-mode-banner" hidden>
</main>
'''

        upgraded = patcher.add_launcher_html(old)

        self.assertIn('class="aos-launcher"', upgraded)
        self.assertEqual(upgraded.count('class="aos-launch-tile"'), 6)
        self.assertLess(upgraded.index('class="aos-launcher"'), upgraded.index('id="safe-mode-banner"'))
        self.assertEqual(patcher.add_launcher_html(upgraded), upgraded)
        self.assertIn(".aos-launch-tile::before", patcher.LAUNCHER_CSS)

    def test_time_status_upgrade_is_idempotent(self):
        old = f"""function refreshSystemTime() {{
    {patcher.OLD_TIME_STATUS_SPAWN}
        .then((out) => {{
{patcher.OLD_TIME_STATUS_RENDER}
        }});
}}"""

        upgraded = patcher.upgrade_time_js(old)

        self.assertIn(patcher.TIME_STATUS_SPAWN, upgraded)
        self.assertNotIn(patcher.OLD_TIME_STATUS_SPAWN, upgraded)
        self.assertIn(patcher.TIME_STATUS_RENDER, upgraded)
        self.assertEqual(patcher.upgrade_time_js(upgraded), upgraded)

    def test_fresh_time_panel_uses_privilege_only_for_clock_changes(self):
        self.assertIn(patcher.TIME_STATUS_SPAWN, patcher.TIME_JS)
        self.assertNotIn(patcher.OLD_TIME_STATUS_SPAWN, patcher.TIME_JS)
        self.assertIn(patcher.TIME_STATUS_RENDER, patcher.TIME_JS)
        self.assertIn(
            '{ superuser: "require", err: "message" }',
            patcher.TIME_JS,
        )


if __name__ == "__main__":
    unittest.main()
