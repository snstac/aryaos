#!/usr/bin/env python3
"""Regression checks for service defaults and drop-ins."""

import json
from pathlib import Path
import unittest


ROOT = Path(__file__).parents[1]


class ServiceDefaultsTestCase(unittest.TestCase):
    def test_config_backup_preserves_private_gutcheck_settings(self):
        backup = (
            ROOT / "shared_files/aryaos/aryaos-config-backup"
        ).read_text()
        verifier = (ROOT / "scripts/verify-image.sh").read_text()
        hil = (ROOT / "scripts/aryaos-test/tests/02-config.sh").read_text()

        config_paths = backup.split("config_paths() {", 1)[1].split("\n}", 1)[0]
        secret_paths = backup.split("secret_paths() {", 1)[1].split("\n}", 1)[0]

        self.assertIn("etc/default/acarsdec", config_paths)
        self.assertNotIn("etc/default/gutcheck", config_paths)
        self.assertIn("etc/default/gutcheck", secret_paths)
        self.assertIn("ACARS decoder settings included in config backups", verifier)
        self.assertIn("ACARS decoder settings included in config backups", hil)
        self.assertIn("Gutcheck settings included in full config backups", verifier)
        self.assertIn("Gutcheck settings included in full config backups", hil)

    def test_node_red_socket_io_parser_memory_exhaustion_fix(self):
        lock = json.loads(
            (ROOT / "shared_files/node-red/package-lock.json").read_text()
        )
        version = lock["packages"]["node_modules/socket.io-parser"]["version"]

        self.assertGreaterEqual(
            tuple(int(part) for part in version.split(".")),
            (4, 2, 7),
        )

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
            "cockpit-cotbridge": "1.2.2",
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
        self.assertIn("TimeoutStopSec=15s", overlay_override)
        self.assertIn("ais-catcher.service.d/aryaos-private.conf", builder)
        self.assertIn("ais-catcher-rtl@.service", builder)
        self.assertIn("aryaos-ais-sdr.service", builder)

    def test_image_requires_aiscot_with_reconnect_safe_listener_cleanup(self):
        verifier = (ROOT / "scripts/verify-image.sh").read_text()
        hil = (ROOT / "scripts/aryaos-test/tests/05-packages.sh").read_text()

        self.assertIn("require_pkg_version aiscot 7.3.1", verifier)
        self.assertIn("require_package_version aiscot 7.3.1", hil)

    def test_node_red_installer_retries_transient_release_asset_failures(self):
        stage = (
            ROOT / "stages/stage-node-red/00-install/00-run.sh"
        ).read_text()

        self.assertIn("--retry-all-errors", stage)
        self.assertIn("--retry 5", stage)
        self.assertIn("api.github.com/repos/node-red/linux-installers/releases/assets/", stage)
        self.assertIn("Accept: application/octet-stream", stage)
        self.assertIn("NODE_RED_LINUX_INSTALLER_SHA256", stage)
        self.assertIn("sha256sum -c -", stage)

        workflow = (ROOT / ".github/workflows/pi-gen.yml").read_text()
        self.assertIn("Accept: application/octet-stream", workflow)
        self.assertIn("/tmp/node-red-installer", workflow)
        self.assertIn("sha256sum -c -", workflow)

    def test_overlay_packages_binary_serial_discovery(self):
        builder = (ROOT / "scripts/build-aryaos-overlay-deb.sh").read_text()
        assign = (ROOT / "shared_files/aryaos/aryaos-serial-assign").read_text()
        postinst = (ROOT / "packaging/aryaos-overlay/postinst").read_text()
        verifier = (ROOT / "scripts/verify-image.sh").read_text()
        hil = (ROOT / "scripts/aryaos-test/tests/05-packages.sh").read_text()

        self.assertIn('aryaos-serial-classify" "/usr/local/libexec/aryaos/', builder)
        self.assertIn('aryaos-serial-assign" "/usr/local/sbin/aryaos-serial-assign', builder)
        self.assertIn("aryaos-serial-assign.service", builder)
        self.assertIn("--no-block try-restart gpsd.service", assign)
        self.assertIn("--no-block try-restart ais-catcher.service", assign)
        self.assertIn("is_adsbee_device", assign)
        self.assertIn("ADSBee Beast serial, handled by readsb", assign)
        self.assertIn("configured_gps_device", assign)
        self.assertIn("preserved verified assignment", assign)
        self.assertIn('[[ -e "$configured" ]] || return 1', assign)
        self.assertIn('$configured_real" != "$ais_real', assign)
        self.assertIn('if [[ -n "$configured_gps" ]]', assign)
        self.assertIn('gps_dev="$configured_gps"', assign)
        self.assertIn("gpsd_config=/etc/default/gpsd", postinst)
        self.assertIn('if [ ! -f "$gpsd_config" ]', postinst)
        self.assertIn(
            "for gpsd_key in START_DAEMON GPSD_OPTIONS OPTIONS DEVICES USBAUTO",
            postinst,
        )
        self.assertIn('grep -q "^${gpsd_key}=" "$gpsd_config"', postinst)
        self.assertIn("require_pkg_version aryaos-overlay 2.1.14", verifier)
        self.assertIn("require_package_version aryaos-overlay 2.1.14", hil)
        self.assertIn('[[ "$current" == "$desired" ]] && return 1', assign)
        self.assertIn(
            'set_kv "$GPSD_DEF" DEVICES "$gps_dev" || true', assign
        )
        self.assertIn(
            'set_kv "$AIS_DEF" SERIAL_PORT "$ais_dev" && ais_changed=1', assign
        )
        self.assertIn(
            'set_kv "$AIS_DEF" SERIAL_BAUDRATE "$ais_baud" bare && ais_changed=1',
            assign,
        )
        self.assertIn('if [[ "$ais_changed" == 1 ]]', assign)
        serial_unit = (
            ROOT
            / "shared_files/aryaos/systemd/aryaos-serial-assign.service"
        ).read_text()
        self.assertIn("Before=ais-catcher.service gpsd.service readsb.service", serial_unit)

    def test_dronescout_hil_survives_rotated_startup_heartbeat(self):
        hil = (
            ROOT / "scripts/aryaos-test/tests/06-optional-uas.sh"
        ).read_text()
        self.assertIn(
            "MAVLink heartbeat received|Processing RID data", hil
        )

    def test_overlay_migrates_dronescout_crlf_setting(self):
        builder = (ROOT / "scripts/build-aryaos-overlay-deb.sh").read_text()
        postinst = (ROOT / "packaging/aryaos-overlay/postinst").read_text()
        self.assertIn("dronecot-dronescout.default", builder)
        self.assertIn("SERIAL_CRLF_NORMALIZE=%s", postinst)
        self.assertIn("dronescout_crlf=1", postinst)
        self.assertIn("ID_VENDOR_ID=303a", postinst)
        self.assertIn(
            "try-restart lincot.service acarsdec.service "
            "dronecot-dronescout.service",
            postinst,
        )

    def test_dronecot_instances_have_distinct_runtime_status(self):
        builder = (ROOT / "scripts/build-aryaos-overlay-deb.sh").read_text()
        postinst = (ROOT / "packaging/aryaos-overlay/postinst").read_text()
        health = (ROOT / "shared_files/aryaos/aryaos-health").read_text()
        image_check = (ROOT / "scripts/verify-image.sh").read_text()
        hil_check = (
            ROOT / "scripts/aryaos-test/tests/05-packages.sh"
        ).read_text()

        for instance in ("dronescout", "wifi", "ble"):
            name = f"dronecot-{instance}"
            defaults = (
                ROOT / f"shared_files/aryaos/{name}.default"
            ).read_text()
            self.assertIn(f"STATUS_APP={name}", defaults)
            self.assertIn(f'aryaos/{name}.default"', builder)
            self.assertIn(f'"{name}"', health)
            self.assertIn(f"^STATUS_APP={name}$", image_check)

        self.assertIn("for dronecot_instance in dronescout wifi ble", postinst)
        self.assertIn("STATUS_APP=dronecot-%s", postinst)
        self.assertIn("require_pkg_version dronecot 2.3.9", image_check)
        self.assertIn("require_package_version dronecot 2.3.9", hil_check)

    def test_overlay_keeps_network_gps_core_active(self):
        postinst = (ROOT / "packaging/aryaos-overlay/postinst").read_text()

        self.assertIn("systemctl enable --now gpscot.service", postinst)
        self.assertIn("systemctl restart aryaos-serial-assign.service", postinst)

    def test_image_requires_in_process_reconnect_for_custom_clients(self):
        image_check = (ROOT / "scripts/verify-image.sh").read_text()
        hil_check = (
            ROOT / "scripts/aryaos-test/tests/05-packages.sh"
        ).read_text()

        for package, version in (
            ("pytak", "7.5.2"),
            ("gpscot", "2.0.1"),
            ("gdlcot", "2.0.1"),
            ("sikw00fcot", "1.0.2"),
        ):
            self.assertIn(
                f"require_pkg_version {package} {version}", image_check
            )
            self.assertIn(
                f"require_package_version {package} {version}", hil_check
            )

    def test_sikw00fcot_site_config_survives_package_upgrades(self):
        dropin = (
            ROOT
            / "shared_files/cotbridge/systemd/sikw00fcot.service.d/aryaos-config.conf"
        ).read_text()
        builder = (ROOT / "scripts/build-aryaos-overlay-deb.sh").read_text()
        verifier = (ROOT / "scripts/verify-image.sh").read_text()
        hil = (ROOT / "scripts/aryaos-test/tests/02-config.sh").read_text()

        self.assertIn("EnvironmentFile=\n", dropin)
        self.assertIn(
            "EnvironmentFile=-/etc/aryaos/aryaos-config.txt", dropin
        )
        self.assertIn("EnvironmentFile=/etc/default/sikw00fcot", dropin)
        self.assertIn("sikw00fcot.service.d/aryaos-config.conf", builder)
        self.assertIn("sikw00fcot.service.d/aryaos-config.conf", verifier)
        self.assertIn("sikw00fcot.service.d/aryaos-config.conf", hil)

    def test_overlay_packages_gateway_health_cli(self):
        builder = (ROOT / "scripts/build-aryaos-overlay-deb.sh").read_text()
        health = (ROOT / "shared_files/aryaos/aryaos-health").read_text()
        sudoers = (
            ROOT / "shared_files/aryaos/aryaos-gutcheck-health.sudoers"
        ).read_text()
        dropin = (
            ROOT
            / "shared_files/aryaos/systemd/gutcheck.service.d/aryaos-health.conf"
        ).read_text()
        postinst = (ROOT / "packaging/aryaos-overlay/postinst").read_text()
        verifier = (ROOT / "scripts/verify-image.sh").read_text()

        self.assertIn(
            'aryaos-health" "/usr/local/sbin/aryaos-health"', builder
        )
        self.assertIn("aryaos-gutcheck-health.sudoers", builder)
        self.assertIn("gutcheck.service.d/aryaos-health.conf", builder)
        self.assertIn(
            "gutcheck ALL=(root) NOPASSWD: ARYAOS_GUTCHECK_HEALTH", sudoers
        )
        self.assertNotIn("ALL=(ALL)", sudoers)
        self.assertIn(
            "^Cmnd_Alias ARYAOS_GUTCHECK_HEALTH = "
            "/usr/local/sbin/aryaos-health --json$",
            verifier,
        )
        self.assertIn(
            r"^gutcheck ALL=\(root\) NOPASSWD: "
            r"ARYAOS_GUTCHECK_HEALTH$",
            verifier,
        )
        self.assertNotIn(
            "^gutcheck ALL=(root) NOPASSWD: ARYAOS_GUTCHECK_HEALTH$",
            verifier,
        )
        self.assertIn("/usr/local/sbin/aryaos-health --json", dropin)
        self.assertIn("dronecot-dronescout.service gutcheck.service", postinst)
        self.assertIn('"UnitFileState"', health)
        self.assertIn('!= "disabled"', health)
        self.assertNotIn('"gutcheck",', health)

    def test_overlay_orders_feeders_after_cotbridge(self):
        builder = (ROOT / "scripts/build-aryaos-overlay-deb.sh").read_text()

        self.assertIn(
            "for svc in adsbcot aiscot dronecot sikw00fcot lincot aircot",
            builder,
        )
        self.assertIn(
            'after-cotbridge.conf" "/etc/systemd/system/${svc}.service.d/',
            builder,
        )

    def test_overlay_migrates_site_output_and_adsb_fields(self):
        postinst = (ROOT / "packaging/aryaos-overlay/postinst").read_text()
        builder = (ROOT / "scripts/build-aryaos-overlay-deb.sh").read_text()
        helper = (ROOT / "shared_files/aryaos/aryaos-site-output").read_text()
        verifier = (ROOT / "scripts/verify-image.sh").read_text()
        hil = (ROOT / "scripts/aryaos-test/tests/02-config.sh").read_text()

        for key in (
            "ARYAOS_COT_OUTPUT_URL",
            "ARYAOS_ADSB_1090_SOURCE",
            "ARYAOS_ADSB_1090_DEVICE",
            "ARYAOS_UAT_978_DEVICE",
        ):
            self.assertIn(key, postinst)
        self.assertIn("--device-type modesbeast", postinst)
        self.assertIn("usb-Raspberry_Pi_Pico_", postinst)
        self.assertIn("ARYAOS_ADSB_1090_SOURCE=adsbee", postinst)
        self.assertIn('aryaos-site-output" "/usr/local/sbin/aryaos-site-output', builder)
        self.assertIn("aryaos-site-output --migrate", postinst)
        self.assertIn("LEGACY_SECTIONS", helper)
        self.assertIn('cp.set(legacy, "enabled", "false")', helper)
        for check in (verifier, hil):
            self.assertIn("lane:site-output", check)
            self.assertNotIn("lane:local-to-mesh", check)
            self.assertNotIn("lane:local-to-takserver", check)

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
