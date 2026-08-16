#!/usr/bin/env python3
"""Regression tests for the destructive zeroize helper's static contract."""

from pathlib import Path
import re
import unittest


ROOT = Path(__file__).parents[1]
ZEROIZE = ROOT / "shared_files/aryaos/aryaos-zeroize"


class ZeroizeContractTestCase(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.script = ZEROIZE.read_text()

    def test_resets_cotbridge_target_to_packaged_default(self):
        wipe = "wipe /etc/aryaos/aryaos-config.txt /etc/cotbridge.ini"
        restore = (
            "install -D -m 0644 -o root -g root "
            "/usr/share/aryaos/defaults/cotbridge.ini /etc/cotbridge.ini"
        )
        self.assertIn(wipe, self.script)
        self.assertIn(restore, self.script)
        self.assertLess(self.script.index(wipe), self.script.index(restore))

    def test_invalidates_local_password_and_key_credentials(self):
        self.assertIn("| chpasswd", self.script)
        self.assertIn("chage -d 0 pi", self.script)
        self.assertIn("passwd -l root", self.script)
        self.assertIn(
            "wipe /root/.ssh/authorized_keys /home/*/.ssh/authorized_keys",
            self.script,
        )
        self.assertIn("rm -f /etc/sudoers.d/aryaos-lab", self.script)
        self.assertNotIn("sed -i '/aryaos-dev-lab/d'", self.script)

    def test_bootstrap_password_matches_image_default(self):
        config = (ROOT / "config.docker").read_text()
        configured = re.search(r'^FIRST_USER_PASS="([^"]+)"$', config, re.M)
        reset = re.search(r"printf 'pi:([^\\]+)\\n' \| chpasswd", self.script)
        self.assertIsNotNone(configured)
        self.assertIsNotNone(reset)
        self.assertEqual(configured.group(1), reset.group(1))

    def test_backup_restore_repairs_missing_web_tls_before_service_restart(self):
        backup = (ROOT / "shared_files/aryaos/aryaos-config-backup").read_text()
        regenerate = "make-ssl-cert generate-default-snakeoil --force-overwrite"
        restart = "systemctl try-restart ${svcs} lighttpd.service"
        self.assertIn("snakeoil-combined.pem", backup)
        self.assertIn(regenerate, backup)
        self.assertIn(".web-tls-regenerated", backup)
        self.assertLess(backup.index(regenerate), backup.index(restart))


if __name__ == "__main__":
    unittest.main(verbosity=2)
