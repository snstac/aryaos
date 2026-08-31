#!/usr/bin/env python3
"""Controller-side tests for the SSH HIL runner."""

from __future__ import annotations

import os
import pathlib
import stat
import subprocess
import tempfile
import unittest


ROOT = pathlib.Path(__file__).resolve().parent.parent
RUNNER = ROOT / "scripts/aryaos-test/run.sh"
SERVICES = ROOT / "scripts/aryaos-test/tests/01-services.sh"


class HilRunnerTestCase(unittest.TestCase):
    @staticmethod
    def _write_executable(path: pathlib.Path, body: str) -> None:
        path.write_text(body, encoding="utf-8")
        path.chmod(path.stat().st_mode | stat.S_IXUSR)

    def test_password_ssh_primes_sudo_without_exposing_password(self):
        """A field image can keep password-required sudo and still run HIL."""
        with tempfile.TemporaryDirectory() as tmp:
            temp = pathlib.Path(tmp)
            fake_bin = temp / "bin"
            fake_bin.mkdir()
            log = temp / "calls.log"
            stamp = temp / "sudo.stamp"

            self._write_executable(
                fake_bin / "sshpass",
                """#!/bin/sh
test "$1" = -e && shift
export FAKE_VIA_SSHPASS=1
exec "$@"
""",
            )
            self._write_executable(
                fake_bin / "scp",
                """#!/bin/sh
printf 'scp %s\\n' "$*" >>"$FAKE_HIL_LOG"
exit 0
""",
            )
            self._write_executable(
                fake_bin / "ssh",
                """#!/bin/sh
printf 'ssh %s\\n' "$*" >>"$FAKE_HIL_LOG"
case "$*" in
  *"sudo -n true"*) test -f "$FAKE_SUDO_STAMP"; exit $? ;;
  *"sudo -S -p '' -v"*)
    IFS= read -r supplied
    test "$supplied" = "$FAKE_EXPECTED_PASSWORD" || exit 42
    : >"$FAKE_SUDO_STAMP"
    exit 0
    ;;
esac
test "${FAKE_VIA_SSHPASS:-}" = 1
""",
            )

            password = "synthetic-release-password"
            env = os.environ.copy()
            env.update(
                {
                    "PATH": f"{fake_bin}:{env['PATH']}",
                    "ARYAOS_SSH": "pi@release-under-test",
                    "ARYAOS_DEV_PI_PASSWORD": password,
                    "ARYAOS_EXPECT_CAPABILITIES": "adsb rid",
                    "ARYAOS_DEV_PI_SKIP_KEY": "1",
                    "FAKE_HIL_LOG": str(log),
                    "FAKE_SUDO_STAMP": str(stamp),
                    "FAKE_EXPECTED_PASSWORD": password,
                }
            )
            result = subprocess.run(
                [str(RUNNER)],
                cwd=ROOT,
                env=env,
                text=True,
                capture_output=True,
                timeout=30,
                check=False,
            )

            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn("SSH: using password", result.stdout)
            self.assertIn("Sudo: password credential cached", result.stdout)
            self.assertIn("Required capabilities: adsb rid", result.stdout)
            calls = log.read_text(encoding="utf-8")
            self.assertIn("sudo -S -p '' -v", calls)
            self.assertIn("ARYAOS_EXPECT_CAPABILITIES='adsb rid'", calls)
            self.assertNotIn(password, calls)

    def test_services_module_enforces_required_capability_subset(self):
        with tempfile.TemporaryDirectory() as tmp:
            temp = pathlib.Path(tmp)
            fake_bin = temp / "bin"
            fake_bin.mkdir()
            config = temp / "aryaos-config.txt"
            config.write_text('ARYAOS_CAPABILITIES="adsb"\n', encoding="utf-8")
            self._write_executable(
                fake_bin / "systemctl",
                """#!/bin/sh
case "$*" in
  *"-p LoadState --value"*) echo loaded ;;
  *"--failed"*) : ;;
  *"is-active --quiet"*|*"is-enabled --quiet"*) exit 0 ;;
  *"is-active"*) echo active ;;
esac
exit 0
""",
            )
            env = os.environ.copy()
            env.update(
                {
                    "PATH": f"{fake_bin}:{env['PATH']}",
                    "ARYAOS_CONFIG_FILE": str(config),
                    "ARYAOS_EXPECT_CAPABILITIES": "adsb rid",
                }
            )
            result = subprocess.run(
                ["bash", str(SERVICES)],
                cwd=ROOT,
                env=env,
                text=True,
                capture_output=True,
                timeout=10,
                check=False,
            )
            output = result.stdout + result.stderr
            self.assertNotEqual(result.returncode, 0, output)
            self.assertIn("OK   required capability adsb enabled", output)
            self.assertIn("FAIL required capability rid not enabled", output)

    def test_air_profile_automatically_requires_adsb_and_rid(self):
        with tempfile.TemporaryDirectory() as tmp:
            temp = pathlib.Path(tmp)
            fake_bin = temp / "bin"
            fake_bin.mkdir()
            log = temp / "calls.log"
            self._write_executable(
                fake_bin / "scp",
                "#!/bin/sh\nprintf 'scp %s\\n' \"$*\" >>\"$FAKE_HIL_LOG\"\n",
            )
            self._write_executable(
                fake_bin / "ssh",
                "#!/bin/sh\nprintf 'ssh %s\\n' \"$*\" >>\"$FAKE_HIL_LOG\"\nexit 0\n",
            )
            env = os.environ.copy()
            env.update(
                {
                    "PATH": f"{fake_bin}:{env['PATH']}",
                    "ARYAOS_SSH": "pi@air-under-test",
                    "ARYAOS_TEST_PROFILE": "air",
                    "ARYAOS_DEV_PI_SKIP_KEY": "1",
                    "FAKE_HIL_LOG": str(log),
                }
            )
            result = subprocess.run(
                [str(RUNNER)], cwd=ROOT, env=env, text=True,
                capture_output=True, timeout=30, check=False,
            )

            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn("Profile: air", result.stdout)
            self.assertIn("Required capabilities: adsb rid", result.stdout)
            calls = log.read_text(encoding="utf-8")
            self.assertIn("ARYAOS_TEST_PROFILE='air'", calls)
            self.assertIn("ARYAOS_EXPECT_CAPABILITIES='adsb rid'", calls)


if __name__ == "__main__":
    unittest.main()
