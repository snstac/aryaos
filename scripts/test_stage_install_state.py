"""Run the aryaos-state install lines of the pi-gen stage into an empty rootfs."""
import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
RUN_SH = REPO / "stages" / "stage-aryaos" / "00-install" / "00-run.sh"
SHARED = REPO / "shared_files"


def state_lines():
    out = []
    for ln in RUN_SH.read_text().splitlines():
        if "aryaos/state" in ln or "aryaos-state" in ln:
            out.append(ln)
    return out


class StageInstallState(unittest.TestCase):
    def test_install_into_empty_rootfs(self):
        lines = state_lines()
        self.assertTrue(any(" -d " in ln for ln in lines), "no mkdir -d line")
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "usr/local/sbin").mkdir(parents=True)
            self.assertFalse((root / "usr/share/aryaos").exists())
            script = "set -e\n" + "\n".join(lines) + "\n"
            env = {"PATH": "/usr/bin:/bin", "ROOTFS_DIR": str(root),
                   "SHARED_FILES": str(SHARED)}
            r = subprocess.run(["bash", "-c", script], env=env,
                               capture_output=True, text=True)
            self.assertEqual(r.returncode, 0, r.stderr)
            st = root / "usr/share/aryaos/state"
            for n in ("schema", "safe-mode", "emcon", "zeroize"):
                self.assertTrue((st / (n + ".json")).is_file(), n)
            cli = root / "usr/local/sbin/aryaos-state"
            env2 = {"PATH": "/usr/bin:/bin", "ARYAOS_STATE_CONTRACTS": str(st)}
            r = subprocess.run(["/usr/bin/python3", str(cli), "list", "--json"],
                               env=env2, capture_output=True, text=True)
            self.assertEqual(r.returncode, 0, r.stderr)
            data = json.loads(r.stdout)
            names = data["machines"]
            self.assertEqual(len(names), 3, r.stdout)


if __name__ == "__main__":
    unittest.main()
