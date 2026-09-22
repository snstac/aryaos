#!/usr/bin/env python3
# Copyright Sensors & Signals LLC https://www.snstac.com/
# SPDX-License-Identifier: Apache-2.0
"""Regression tests for aryaos-config-backup's --no-secrets redaction.

The live failure (aryaos-a29c, 2026-09-22). `--no-secrets` is the mode people
rely on before attaching a backup to a ticket or handing one to a customer. It
correctly dropped system-connections, gutcheck and the Node-RED credential
files -- and then shipped /etc/comitup.conf verbatim, including

    ap_password: <the Wi-Fi onboarding hotspot WPA2 passphrase>

in cleartext, because comitup.conf sits in config_paths (correctly: ap_name and
the rest are ordinary config) and nothing scrubbed the one secret key in it.

The trap is that the passphrase only appears AFTER an operator sets a hotspot
password -- which is exactly what the "Secure the device" checklist instructs.
So a box was only vulnerable once it had been correctly hardened, and an
unhardened box produced a clean-looking backup.

aryaos-support-bundle was never affected: its redactor matches key names
containing PASSWORD, which catches ap_password.
"""

import os
import re
import subprocess
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
BACKUP = os.path.join(HERE, "..", "shared_files", "aryaos", "aryaos-config-backup")

SECRET = "aos-47V3rQW9jyILdD3e"
SAMPLE_CONF = f"""# comitup configuration
ap_name: AryaOS-a29c
enable_appliance_mode: false
ap_password: {SECRET}
external_callback: /usr/local/sbin/comitup-callback.sh
"""


class RedactedKeysTestCase(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        with open(BACKUP) as fh:
            cls.src = fh.read()

    def _list(self, func):
        m = re.search(rf"{func}\(\) \{{\n\tcat <<'EOF'\n(.*?)\nEOF", self.src, re.S)
        self.assertIsNotNone(m, f"{func} not found")
        return [l for l in m.group(1).split("\n") if l.strip()]

    def test_comitup_conf_is_still_backed_up(self):
        """Dropping the file entirely would lose real config (ap_name, etc.)."""
        self.assertIn("etc/comitup.conf", self._list("config_paths"))

    def test_comitup_password_is_registered_for_redaction(self):
        self.assertIn("etc/comitup.conf:ap_password", self._list("redacted_keys"))

    def test_redaction_is_only_applied_without_secrets(self):
        """A full backup must stay restorable, passphrase included."""
        idx = self.src.index("local -a redacted_args=()")
        window = self.src[idx:idx + 200]
        self.assertIn('if [[ "${include_secrets}" == "0" ]]', window)

    def test_redacted_file_replaces_the_live_one(self):
        """Staging a copy is useless if the original is still tarred from /."""
        idx = self.src.index("local -a redacted_args=()")
        window = self.src[idx:idx + 900]
        self.assertIn("unset 'paths[i]'", window, "original path must be removed")
        self.assertIn('paths=("${paths[@]}")', window, "array must be re-packed")


class RedactionBehaviourTestCase(unittest.TestCase):
    """Exercise the actual sed expression the script uses."""

    @classmethod
    def setUpClass(cls):
        with open(BACKUP) as fh:
            src = fh.read()
        m = re.search(r'sed -E "(s/\^\(\[\[:space:\]\]\*.*?)"', src, re.S)
        assert m, "redaction sed expression not found"
        cls.expr = m.group(1)

    def redact(self, text, key="ap_password"):
        expr = self.expr.replace("${key}", key)
        with tempfile.TemporaryDirectory() as td:
            src = os.path.join(td, "in.conf")
            with open(src, "w") as fh:
                fh.write(text)
            out = subprocess.run(
                ["sed", "-E", expr, src], capture_output=True, text=True, timeout=30
            )
            self.assertEqual(out.returncode, 0, out.stderr)
            return out.stdout

    def test_passphrase_is_removed(self):
        got = self.redact(SAMPLE_CONF)
        self.assertNotIn(SECRET, got, "the WPA2 passphrase survived redaction")

    def test_redaction_marker_is_left_behind(self):
        """Silently deleting the line would look like 'no password was set'."""
        self.assertIn("[REDACTED]", self.redact(SAMPLE_CONF))

    def test_ordinary_config_is_preserved(self):
        got = self.redact(SAMPLE_CONF)
        self.assertIn("ap_name: AryaOS-a29c", got)
        self.assertIn("enable_appliance_mode: false", got)
        self.assertIn("external_callback:", got)

    def test_commented_out_password_is_untouched(self):
        """The shipped default has '# ap_password' as documentation."""
        got = self.redact("# ap_password: supersecretpassword\n")
        self.assertIn("# ap_password: supersecretpassword", got)

    def test_indented_key_is_still_redacted(self):
        got = self.redact(f"   ap_password:   {SECRET}\n")
        self.assertNotIn(SECRET, got)

    def test_file_without_the_key_is_unchanged(self):
        text = "ap_name: AryaOS-0000\n"
        self.assertEqual(self.redact(text), text)


if __name__ == "__main__":
    unittest.main(verbosity=2)
