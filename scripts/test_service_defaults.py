#!/usr/bin/env python3
"""Regression checks for service defaults and drop-ins."""

from pathlib import Path
import unittest


ROOT = Path(__file__).parents[1]


class ServiceDefaultsTestCase(unittest.TestCase):
    def test_gpsd_defines_both_option_variables_used_by_vendor_unit(self):
        defaults = (ROOT / "shared_files/aryaos/gpsd.default").read_text()

        self.assertIn('GPSD_OPTIONS="-n"', defaults)
        self.assertIn('OPTIONS=""', defaults)

    def test_bluetooth_directory_mode_matches_debian_packaging(self):
        dropin = (
            ROOT
            / "shared_files/aryaos/systemd/bluetooth.service.d/aryaos-directory-mode.conf"
        ).read_text()
        builder = (ROOT / "scripts/build-aryaos-overlay-deb.sh").read_text()

        self.assertIn("ConfigurationDirectoryMode=0755", dropin)
        self.assertIn("bluetooth.service.d/aryaos-directory-mode.conf", builder)

    def test_missing_optional_ktls_module_is_overridden(self):
        override = (
            ROOT
            / "shared_files/aryaos/modules-load.d/lighttpd-mod-openssl.conf"
        ).read_text()
        builder = (ROOT / "scripts/build-aryaos-overlay-deb.sh").read_text()
        image_stage = (
            ROOT / "stages/stage-aryaos/00-install/00-run.sh"
        ).read_text()

        self.assertNotIn("\ntls\n", f"\n{override}\n")
        self.assertIn("optional kernel TLS module", override)
        self.assertIn("modules-load.d/lighttpd-mod-openssl.conf", builder)
        self.assertIn("modules-load.d/lighttpd-mod-openssl.conf", image_stage)

    def test_acars_start_limit_is_in_unit_section(self):
        unit = (ROOT / "shared_files/aryaos/systemd/acarsdec.service").read_text()
        unit_section, service_section = unit.split("\n[Service]\n", 1)

        self.assertIn("StartLimitIntervalSec=300", unit_section)
        self.assertIn("StartLimitBurst=5", unit_section)
        self.assertNotIn("StartLimit", service_section)

    def test_overlay_packages_binary_serial_discovery(self):
        builder = (ROOT / "scripts/build-aryaos-overlay-deb.sh").read_text()

        self.assertIn('aryaos-serial-classify" "/usr/local/libexec/aryaos/', builder)
        self.assertIn('aryaos-serial-assign" "/usr/local/sbin/aryaos-serial-assign', builder)
        self.assertIn("aryaos-serial-assign.service", builder)

    def test_overlay_keeps_network_gps_core_active(self):
        postinst = (ROOT / "packaging/aryaos-overlay/postinst").read_text()

        self.assertIn("systemctl enable --now gpstak.service", postinst)
        self.assertIn("systemctl restart aryaos-serial-assign.service", postinst)


if __name__ == "__main__":
    unittest.main(verbosity=2)
