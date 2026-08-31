#!/usr/bin/env python3
"""Behavior tests for the legacy role presets exposed to Cockpit."""

import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).parents[1]
ROLE = ROOT / "shared_files/aryaos/aryaos-role"


class RolePresetTestCase(unittest.TestCase):
    def test_air_cuas_and_multi_include_dronescout(self):
        with tempfile.TemporaryDirectory() as root:
            config = Path(root) / "aryaos-config.txt"
            config.write_text(
                'ARYAOS_ROLE="air"\n'
                'ARYAOS_CAPABILITIES="adsb rid"\n'
                'ARYAOS_ADSB_DECODER=readsb\n',
                encoding="utf-8",
            )
            env = os.environ.copy()
            env["ARYAOS_SITE_CONFIG"] = str(config)
            result = subprocess.run(
                [str(ROLE), "list"],
                env=env,
                text=True,
                capture_output=True,
                check=False,
                timeout=10,
            )

        self.assertEqual(result.returncode, 0, result.stderr)
        payload = json.loads(result.stdout)
        self.assertEqual(payload["current"], "air")
        self.assertEqual(payload["capabilities"], "adsb rid")
        for preset in ("air", "cuas", "multi"):
            self.assertIn(
                "dronecot-dronescout", payload["roles"][preset]["units"]
            )
        self.assertNotIn("dronecot-dji", payload["roles"]["air"]["units"])
        self.assertIn("dronecot-dji", payload["roles"]["cuas"]["units"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
