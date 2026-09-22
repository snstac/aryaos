#!/usr/bin/env python3
# Copyright Sensors & Signals LLC https://www.snstac.com/
# SPDX-License-Identifier: Apache-2.0
"""Behaviour tests for aryaos-safe-mode's restore decision and unit coverage.

Two live failures on aryaos-a29c (DragonEgg, capabilities="acars"), 2026-09-22.

1. Clearing safe mode re-tasked the box.

       configured_role() { local role="multi"; ...ARYAOS_ROLE...; }
       start_sensors()   { aryaos-role set "$(configured_role)"; }

   Capabilities are the model; ARYAOS_ROLE is a legacy alias that aryaos-role
   only writes when the capability set matches a legacy preset. "acars" has no
   preset, so aryaos-role persists ARYAOS_ROLE="". The empty value fell through
   to the "multi" default, so `aryaos-safe-mode off` ran `aryaos-role set multi`
   and silently re-tasked the box to "adsb ais dji rid sik sapient" -- ACARS
   off, readsb started on a LimeSDR it cannot drive.

2. MANAGED_UNITS was out of sync with aryaos-role despite a comment saying it
   was kept in sync. acarsdec/acarscot and the dronecot-{wifi,ble,dronescout}
   instances were missing from both MANAGED_UNITS and the safe-mode.conf
   drop-in loop, so on an ACARS box safe mode cut USB power while systemd went
   on restarting acarsdec against a radio that had left the bus.
"""

import os
import re
import subprocess
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
SAFE_MODE = os.path.join(HERE, "..", "shared_files", "aryaos", "aryaos-safe-mode")
ROLE = os.path.join(HERE, "..", "shared_files", "aryaos", "aryaos-role")
STAGE_RUN = os.path.join(HERE, "..", "stages", "stage-aryaos", "00-install", "00-run.sh")


def _functions_only(path):
    """The script body with its `case` dispatch removed, so it can be sourced."""
    with open(path) as fh:
        src = fh.read()
    idx = src.index('case "${1:-status}" in')
    return src[:idx]


class ConfiguredRestoreTestCase(unittest.TestCase):
    """What safe mode restores when it is cleared."""

    @classmethod
    def setUpClass(cls):
        cls.body = _functions_only(SAFE_MODE)

    def restore_for(self, config_text):
        """Run configured_restore against a stubbed site config."""
        with tempfile.TemporaryDirectory() as td:
            cfg = os.path.join(td, "aryaos-config.txt")
            if config_text is not None:
                with open(cfg, "w") as fh:
                    fh.write(config_text)
            script = self.body + f'\nCONFIG="{cfg}"\nconfigured_restore\n'
            out = subprocess.run(
                ["bash", "-c", script], capture_output=True, text=True, timeout=30
            )
            self.assertEqual(out.returncode, 0, out.stderr)
            return out.stdout.strip()

    # -- the live failure ------------------------------------------------
    def test_capability_only_box_restores_its_capabilities(self):
        """acars has no legacy preset, so ARYAOS_ROLE is empty. Must not be multi."""
        got = self.restore_for('ARYAOS_CAPABILITIES="acars"\nARYAOS_ROLE=""\n')
        self.assertEqual(got, "caps acars")

    def test_empty_role_never_becomes_multi(self):
        """The exact regression: empty ARYAOS_ROLE fell through to 'multi'."""
        got = self.restore_for('ARYAOS_CAPABILITIES="acars"\nARYAOS_ROLE=""\n')
        self.assertNotIn("multi", got)

    def test_empty_capability_set_is_preserved(self):
        """A relay node runs no sensors. That is a real answer, not 'unset'."""
        got = self.restore_for('ARYAOS_CAPABILITIES=""\nARYAOS_ROLE=""\n')
        self.assertEqual(got, "caps")
        self.assertNotIn("multi", got)

    def test_multi_capability_set_round_trips(self):
        got = self.restore_for('ARYAOS_CAPABILITIES="adsb rid"\nARYAOS_ROLE="air"\n')
        self.assertEqual(got, "caps adsb rid")

    # -- back-compat -----------------------------------------------------
    def test_legacy_config_without_capabilities_uses_the_role(self):
        got = self.restore_for('ARYAOS_ROLE="maritime"\n')
        self.assertEqual(got, "role maritime")

    def test_missing_config_falls_back_to_multi(self):
        self.assertEqual(self.restore_for(None), "role multi")

    # -- the caller ------------------------------------------------------
    def test_start_sensors_dispatches_on_the_restore_form(self):
        """Guards the real file: start_sensors must use caps, not set <role>."""
        with open(SAFE_MODE) as fh:
            src = fh.read()
        start = src.index("start_sensors()")
        body = src[start:start + 1200]
        self.assertIn("aryaos-role caps", body)
        self.assertIn("configured_restore", body)

    def test_empty_capability_set_is_passed_as_none(self):
        """aryaos-role spells the empty set 'none'; bare '' would be a usage error."""
        with open(SAFE_MODE) as fh:
            src = fh.read()
        start = src.index("start_sensors()")
        self.assertIn('caps="none"', src[start:start + 1200])


class ManagedUnitsTestCase(unittest.TestCase):
    """Safe mode must gate every sensor unit aryaos-role can enable."""

    @classmethod
    def setUpClass(cls):
        with open(SAFE_MODE) as fh:
            cls.safe_src = fh.read()
        with open(ROLE) as fh:
            cls.role_src = fh.read()
        with open(STAGE_RUN) as fh:
            cls.stage_src = fh.read()

    def managed_units(self):
        m = re.search(r'MANAGED_UNITS="([^"]*)"', self.safe_src)
        self.assertIsNotNone(m, "MANAGED_UNITS not found")
        return set(m.group(1).split())

    def role_units(self):
        start = self.role_src.index("all_managed_units()")
        body = self.role_src[start:start + 500]
        m = re.search(r"echo \"([^\"]*)\"", body, re.S)
        self.assertIsNotNone(m, "all_managed_units body not found")
        # the echo spans lines with a trailing backslash; drop the continuations
        return {u for u in m.group(1).replace("\\", " ").split() if u}

    def dropin_units(self):
        m = re.search(
            r"safe-mode gate.*?\n\s*for svc in ([^;]+);", self.stage_src, re.S | re.I
        )
        self.assertIsNotNone(m, "safe-mode.conf install loop not found")
        return set(m.group(1).split())

    def test_acars_units_are_managed(self):
        """The live gap: safe mode cut USB but acarsdec kept restarting."""
        managed = self.managed_units()
        for unit in ("acarsdec", "acarscot"):
            self.assertIn(unit, managed, f"{unit} must be stopped in safe mode")

    def test_dronecot_instances_are_managed(self):
        managed = self.managed_units()
        for unit in ("dronecot-wifi", "dronecot-ble", "dronecot-dronescout"):
            self.assertIn(unit, managed, f"{unit} must be stopped in safe mode")

    def test_managed_units_is_a_subset_of_what_role_can_enable(self):
        """The comment claims these are kept in sync. Make that true."""
        missing = self.role_units() - self.managed_units()
        # aryaos-role also sweeps retired/alias units that ship disabled and
        # own no USB peripheral; those need no safe-mode gate.
        allowed = {"adsbxcot", "dronecot", "spotcot"}
        self.assertEqual(
            missing - allowed,
            set(),
            f"aryaos-role can enable units safe mode never stops: {missing - allowed}",
        )

    def test_dropin_loop_matches_managed_units(self):
        """A unit in MANAGED_UNITS with no ConditionPathExists gate still starts."""
        self.assertEqual(
            self.managed_units() - self.dropin_units(),
            set(),
            "units stopped by safe mode but missing the safe-mode.conf drop-in",
        )


if __name__ == "__main__":
    unittest.main(verbosity=2)
