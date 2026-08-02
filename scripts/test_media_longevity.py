#!/usr/bin/env python3
"""Regression tests for bounded RAM-backed writes and RAM-only swap."""

from pathlib import Path
import unittest


ROOT = Path(__file__).parents[1]


class SwapPolicyTestCase(unittest.TestCase):
    def test_sudo_io_history_is_bounded_inside_var_log_tmpfs(self):
        sudoers = (ROOT / "shared_files/aryaos/aryaos.sudoers").read_text()

        self.assertIn("Defaults log_input, log_output", sudoers)
        self.assertIn("Defaults maxseq=128", sudoers)

    def test_rpi_swap_is_pinned_to_file_free_zram(self):
        config = (
            ROOT / "shared_files/aryaos/rpi-swap-aryaos.conf"
        ).read_text()

        self.assertIn("[Main]", config)
        self.assertIn("Mechanism=zram", config)
        self.assertNotIn("Mechanism=zram+file", config)

    def test_overlay_ships_rpi_swap_policy_and_generator_dependency(self):
        builder = (ROOT / "scripts/build-aryaos-overlay-deb.sh").read_text()
        control = (ROOT / "packaging/aryaos-overlay/control").read_text()
        postinst = (ROOT / "packaging/aryaos-overlay/postinst").read_text()

        self.assertIn("rpi-swap-aryaos.conf", builder)
        self.assertIn("/etc/rpi/swap.conf.d/90-aryaos.conf", builder)
        self.assertIn("systemd-zram-generator", control)
        self.assertLess(
            postinst.index("systemctl stop rpi-zram-writeback.timer"),
            postinst.index("systemctl daemon-reload"),
        )
        self.assertGreater(
            postinst.index("systemctl reset-failed rpi-zram-writeback.timer"),
            postinst.index("systemctl daemon-reload"),
        )

    def test_image_removes_build_time_swapfile(self):
        tweaks = (
            ROOT / "stages/stage-adsbcot/00-sys-tweaks/00-run-chroot.sh"
        ).read_text()

        self.assertIn("rm -f /var/swap", tweaks)
        self.assertNotIn("systemd-zram-generator || true", tweaks)


if __name__ == "__main__":
    unittest.main(verbosity=2)
