import os
import json
import subprocess
import unittest
import tempfile
import shutil
from pathlib import Path

class TestAryosState(unittest.TestCase):
    def setUp(self):
        # Create a fake filesystem for the state machines.
        self.temp_dir = tempfile.TemporaryDirectory()
        self.state_root = Path(self.temp_dir.name) / "root"
        self.state_root.mkdir()

        # Create directories and files for sources
        # emcon: /etc/aryaos/emcon (flag)
        (self.state_root / "etc/aryaos").mkdir(parents=True, exist_ok=True)
        (self.state_root / "etc/aryaos/emcon").touch()

        # safe-mode: 
        # /etc/aryaos/safe-mode (flag)
        # /var/lib/aryaos/boot-attempts (counter)
        # /var/lib/aryaos/safe-mode-reason (text)
        (self.state_root / "etc/aryaos/safe-mode").touch()
        (self.state_root / "var/lib/aryaos").mkdir(parents=True, exist_ok=True)
        (self.state_root / "var/lib/aryaos/boot-attempts").write_text("10")
        (self.state_root / "var/lib/aryaos/safe-mode-reason").write_text("test-reason")

        # zeroize: /run/aryaos-zeroize.keep-network (flag)
        (self.state_root / "run").mkdir(parents=True, exist_ok=True)
        (self.state_root / "run/aryaos-zeroize.keep-network").touch()

    def tearDown(self):
        self.temp_dir.cleanup()

    def run_cli(self, command, machine=None, json_mode=False, root=None):
        """Run the aryaos-state CLI."""
        env = os.environ.copy()
        root_path = root if root else self.state_root
        env["ARYAOS_STATE_ROOT"] = str(root_path)

        # Use path relative to repo root
        script_path = os.path.abspath("shared_files/aryaos/aryaos-state")

        args = ["python3", script_path, command]
        if machine:
            args.append(machine)
        if json_mode:
            args.append("--json")

        return subprocess.run(args, capture_output=True, text=True, env=env)

    def verify_contracts(self, base_path):
        """Internal helper to verify contract conformance."""
        schema_path = Path(base_path) / "schema.json"
        with open(schema_path, 'r') as f:
            schema = json.load(f)
        
        if "machine" not in schema["properties"] or "states" not in schema["properties"]:
            return False, "Schema missing core properties"

        for contract_file in Path(base_path).glob("*.json"):
            if contract_file.name == "schema.json":
                continue
            with open(contract_file, 'r') as f:
                contract = json.load(f)
            
            if not all(k in contract for k in ("machine", "states", "initial", "sources")):
                return False, f"Contract {contract_file.name} missing required keys"
            for src in contract["sources"]:
                if not all(k in src for k in ("path", "kind", "meaning")):
                    return False, f"Source in {contract_file.name} missing required keys"
        return True, "OK"

    def test_schema_conformance(self):
        """Verify each contract follows the schema structure."""
        base_path = "shared_files/aryaos/state"
        success, msg = self.verify_contracts(base_path)
        self.assertTrue(success, msg)

    def test_machine_status_emcon(self):
        """Test emcon: flag exists -> on, else off."""
        res = self.run_cli("status", "emcon", json_mode=True)
        self.assertEqual(res.returncode, 0)
        data = json.loads(res.stdout)
        self.assertEqual(data["machine"], "emcon")
        self.assertEqual(data["state"], "on")

        (self.state_root / "etc/aryaos/emcon").unlink()
        res = self.run_cli("status", "emcon", json_mode=True)
        self.assertEqual(res.returncode, 0)
        data = json.loads(res.stdout)
        self.assertEqual(data["state"], "off")

    def test_machine_status_safe_mode(self):
        """Test safe-mode: flag -> safe, counter > 0 -> counting, else normal."""
        # Case 1: Flag missing, counter > 0 -> counting
        with self.subTest(case="counting"):
            (self.state_root / "etc/aryaos/safe-mode").unlink()
            res = self.run_cli("status", "safe-mode", json_mode=True)
            self.assertEqual(res.returncode, 0)
            data = json.loads(res.stdout)
            self.assertEqual(data["state"], "counting")

        # Case 2: Flag present -> safe
        with self.subTest(case="safe"):
            (self.state_root / "etc/aryaos/safe-mode").touch()
            res = self.run_cli("status", "safe-mode", json_mode=True)
            self.assertEqual(res.returncode, 0)
            data = json.loads(res.stdout)
            self.assertEqual(data["state"], "safe")

        # Case 3: Flag missing, counter 0 -> normal
        with self.subTest(case="normal"):
            (self.state_root / "etc/aryaos/safe-mode").unlink()
            (self.state_root / "var/lib/aryaos/boot-attempts").write_text("0")
            res = self.run_cli("status", "safe-mode", json_mode=True)
            self.assertEqual(res.returncode, 0)
            data = json.loads(res.stdout)
            self.assertEqual(data["state"], "normal")

    def test_machine_status_zeroize(self):
        """Test zeroize: flag exists -> zeroizing, else normal."""
        res = self.run_cli("status", "zeroize", json_mode=True)
        self.assertEqual(res.returncode, 0)
        data = json.loads(res.stdout)
        self.assertEqual(data["state"], "zeroizing")

        (self.state_root / "run/aryaos-zeroize.keep-network").unlink()
        res = self.run_cli("status", "zeroize", json_mode=True)
        self.assertEqual(res.returncode, 0)
        data = json.loads(res.stdout)
        self.assertEqual(data["state"], "normal")

    def test_unknown_machine(self):
        """Test error on unknown machine."""
        res = self.run_cli("status", "ghost-machine", json_mode=True)
        self.assertEqual(res.returncode, 1)
        self.assertIn("Error", res.stderr)

    def test_list_command(self):
        """Test 'list' command."""
        res = self.run_cli("list")
        self.assertEqual(res.returncode, 0)
        self.assertIn("emcon", res.stdout)
        self.assertIn("safe-mode", res.stdout)
        self.assertIn("zeroize", res.stdout)

    def test_json_stability(self):
        """Verify --json output is valid and stable."""
        res = self.run_cli("status", "emcon", json_mode=True)
        self.assertEqual(res.returncode, 0)
        data = json.loads(res.stdout)
        self.assertIn("machine", data)
        self.assertIn("state", data)
        self.assertEqual(data["machine"], "emcon")

    def test_unreadable_source(self):
        """Test unreadable source -> unknown."""
        path = self.state_root / "var/lib/aryaos/boot-attempts"
        path.write_text("10")
        path.chmod(0o000)

        (self.state_root / "etc/aryaos/safe-mode").unlink()

        res = self.run_cli("status", "safe-mode", json_mode=True)
        self.assertEqual(res.returncode, 0)
        data = json.loads(res.stdout)
        self.assertEqual(data["state"], "unknown")

        path.chmod(0o644)

if __name__ == "__main__":
    unittest.main()
