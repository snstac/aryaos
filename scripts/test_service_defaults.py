#!/usr/bin/env python3
"""Regression checks for service defaults and drop-ins."""

from pathlib import Path
import unittest


ROOT = Path(__file__).parents[1]


class ServiceDefaultsTestCase(unittest.TestCase):
    def test_gateway_plugin_scroll_release_floor_is_enforced(self):
        image_check = (ROOT / "scripts/verify-image.sh").read_text()
        hil_check = (
            ROOT / "scripts/aryaos-test/tests/05-packages.sh"
        ).read_text()
        aiscot_stage = (
            ROOT / "stages/stage-aiscot/00-install/01-run-chroot.sh"
        ).read_text()
        minimums = {
            "cockpit-adsbcot": "1.2.3",
            "cockpit-aiscot": "1.2.3",
            "cockpit-aprscot": "0.1.1",
            "cockpit-charontak": "1.2.2",
            "cockpit-dronecot": "1.1.3",
            "cockpit-lincot": "1.1.3",
            "cockpit-sapientcot": "0.1.1",
        }

        for package, version in minimums.items():
            requirement = f"require_pkg_version {package} {version}"
            self.assertIn(requirement, image_check)
            self.assertIn(
                f"require_package_version {package} {version}", hil_check
            )

        self.assertIn("overflow-y:[[:space:]]*auto", hil_check)
        self.assertIn("require_cockpit_stylesheets", hil_check)
        self.assertIn('href="index.css"', hil_check)
        self.assertIn('href="../../static/branding.css"', hil_check)
        self.assertIn("v1.2.3/cockpit-aiscot_1.2.3_all.deb", aiscot_stage)
        self.assertIn("v0.1.1/cockpit-aprscot_0.1.1-1_all.deb", aiscot_stage)
        self.assertIn("v0.1.1/cockpit-sapientcot_0.1.1-1_all.deb", aiscot_stage)

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

    def test_ais_receiver_is_private_and_fails_cleanly_when_unassigned(self):
        serial_unit = (ROOT / "shared_files/aiscot/ais-catcher.service").read_text()
        rtl_unit = (
            ROOT / "shared_files/aryaos/systemd/ais-catcher-rtl@.service"
        ).read_text()
        sdr_unit = (
            ROOT / "shared_files/aryaos/systemd/aryaos-ais-sdr.service"
        ).read_text()
        overlay_override = (
            ROOT
            / "shared_files/aryaos/systemd/ais-catcher.service.d/aryaos-private.conf"
        ).read_text()
        builder = (ROOT / "scripts/build-aryaos-overlay-deb.sh").read_text()
        unit_section, service_section = serial_unit.split("\n[Service]\n", 1)

        self.assertIn("StartLimitIntervalSec=300", unit_section)
        self.assertIn("StartLimitBurst=5", unit_section)
        self.assertNotIn("StartLimit", service_section)
        self.assertIn("ExecCondition=/bin/sh -c", service_section)
        for unit in (serial_unit, rtl_unit, sdr_unit, overlay_override):
            self.assertIn("AIS-catcher -X off", unit)
        self.assertIn("ais-catcher.service.d/aryaos-private.conf", builder)
        self.assertIn("ais-catcher-rtl@.service", builder)
        self.assertIn("aryaos-ais-sdr.service", builder)

    def test_overlay_packages_binary_serial_discovery(self):
        builder = (ROOT / "scripts/build-aryaos-overlay-deb.sh").read_text()
        assign = (ROOT / "shared_files/aryaos/aryaos-serial-assign").read_text()

        self.assertIn('aryaos-serial-classify" "/usr/local/libexec/aryaos/', builder)
        self.assertIn('aryaos-serial-assign" "/usr/local/sbin/aryaos-serial-assign', builder)
        self.assertIn("aryaos-serial-assign.service", builder)
        self.assertIn("--no-block try-restart gpsd.service", assign)
        self.assertIn("--no-block try-restart ais-catcher.service", assign)

    def test_overlay_keeps_network_gps_core_active(self):
        postinst = (ROOT / "packaging/aryaos-overlay/postinst").read_text()

        self.assertIn("systemctl enable --now gpstak.service", postinst)
        self.assertIn("systemctl restart aryaos-serial-assign.service", postinst)

    def test_lighttpd_private_devices_exposes_only_pi_firmware_commands(self):
        dropin = (
            ROOT
            / "shared_files/aryaos/systemd/lighttpd.service.d/aryaos-netlink.conf"
        ).read_text()

        self.assertIn("BindReadOnlyPaths=-/dev/vcio_gencmd", dropin)
        self.assertIn("DeviceAllow=/dev/vcio_gencmd rw", dropin)
        self.assertNotIn("PrivateDevices=false", dropin)

    def test_cockpit_branding_packages_canonical_aryaos_mark(self):
        css = (ROOT / "shared_files/aryaos/cockpit/branding.css").read_text()
        mark = (ROOT / "docs/brand/logo/mark-aryaos-rev.svg").read_text()
        builder = (ROOT / "scripts/build-aryaos-overlay-deb.sh").read_text()
        postinst = (ROOT / "packaging/aryaos-overlay/postinst").read_text()
        workflow = (ROOT / ".github/workflows/pi-gen.yml").read_text()

        self.assertIn('url("mark-aryaos-rev.svg")', css)
        self.assertIn("#e4610f", css.lower())
        self.assertNotIn('content: "A"', css)
        self.assertIn('viewBox="0 0 78 50"', mark)
        self.assertIn("#E4610F", mark)
        self.assertIn("docs/brand/logo/mark-aryaos-rev.svg", builder)
        self.assertEqual(postinst.count("mark-aryaos-rev.svg"), 5)
        self.assertIn(
            "${{ github.workspace }}/docs/brand:${{ github.workspace }}/docs/brand:ro",
            workflow,
        )


if __name__ == "__main__":
    unittest.main(verbosity=2)
