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


class BootMediaSafetyTestCase(unittest.TestCase):
    def test_initramfs_rewrites_cmdline_only_after_verified_readback(self):
        script = (
            ROOT / "shared_files/aryaos/initramfs/set_partuuid"
        ).read_text()

        self.assertIn("write_verified", script)
        self.assertIn('cmp -s "$source_file" "$candidate"', script)
        self.assertIn('cmp -s "$source_file" "$destination"', script)
        self.assertIn("remount_boot_for_readback", script)
        self.assertIn('EXPECTED_CMDLINE=/run/', script)
        self.assertNotIn("sed -i 's| resize||g' \"$WORK_DIR/cmdline.txt\"", script)
        self.assertIn('attempt" -le 5', script)

    def test_overlay_rebuilds_initramfs_with_verified_writer(self):
        builder = (ROOT / "scripts/build-aryaos-overlay-deb.sh").read_text()
        hook = (
            ROOT / "shared_files/aryaos/initramfs/zz-aryaos-set-partuuid-hook"
        ).read_text()
        postinst = (ROOT / "packaging/aryaos-overlay/postinst").read_text()
        control = (ROOT / "packaging/aryaos-overlay/control").read_text()

        self.assertIn("zz-aryaos-set-partuuid-hook", builder)
        self.assertIn('${DESTDIR}/scripts/local-bottom/set_partuuid', hook)
        self.assertIn("update-initramfs -u -k all", postinst)
        self.assertIn("initramfs-tools", control)

    def test_hil_rejects_invalid_sd_identity_and_missing_boot_files(self):
        storage_test = (
            ROOT / "scripts/aryaos-test/tests/10-storage.sh"
        ).read_text()

        self.assertIn("install media reports invalid manufacturer ID", storage_test)
        self.assertIn("boot cmdline contains non-printable data", storage_test)
        self.assertIn("kernel_2712.img initramfs_2712", storage_test)
        self.assertIn("required boot artifact", storage_test)


if __name__ == "__main__":
    unittest.main(verbosity=2)
