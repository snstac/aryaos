"""Tests for shared_files/aryaos/aryaos-state (ASM-04). Stdlib unittest only.

1:1 port of the f4038f4 pytest file. Paths derive from __file__, not cwd.
"""
import json
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "shared_files" / "aryaos"
CLI = ROOT / "aryaos-state"
STATE_DIR = ROOT / "state"
CONTRACTS = sorted(p for p in STATE_DIR.glob("*.json") if p.name != "schema.json")
SCHEMA = json.loads((STATE_DIR / "schema.json").read_text())


class SchemaError(Exception):
    """Raised when a document violates the schema."""


def _check_required(doc, schema, where):
    for k in schema.get("required", []):
        if not isinstance(doc, dict) or k not in doc:
            raise SchemaError("%s: missing required key %r" % (where, k))


def check_schema(doc, schema):
    try:
        import jsonschema
    except ImportError:
        jsonschema = None
    if jsonschema is not None:
        try:
            jsonschema.validate(doc, schema)
        except jsonschema.ValidationError as e:
            raise SchemaError(str(e))
        return
    # Fallback: enforce "required" at top level and for every item of each
    # array property whose items schema has "required" (transitions, sources).
    _check_required(doc, schema, "contract")
    for key, sub in schema.get("properties", {}).items():
        items = sub.get("items") if isinstance(sub, dict) else None
        if key in doc and isinstance(items, dict) and items.get("required"):
            for i, item in enumerate(doc[key]):
                _check_required(item, items, "%s[%d]" % (key, i))


def run(root, *args):
    env = {"PATH": "/usr/bin:/bin", "ARYAOS_STATE_ROOT": str(root)}
    return subprocess.run([sys.executable, str(CLI), *args], env=env,
                          capture_output=True, text=True, timeout=30)


def status(root, machine):
    r = run(root, "status", machine, "--json")
    assert r.returncode == 0, r.stderr
    return json.loads(r.stdout)


def touch(root, rel, text=""):
    p = Path(root) / rel.lstrip("/")
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(text)


class TestAryaosState(unittest.TestCase):
    def setUp(self):
        self._td = tempfile.TemporaryDirectory()
        self.addCleanup(self._td.cleanup)
        self.tmp_path = Path(self._td.name)

    def test_three_contracts_present(self):
        self.assertEqual({p.stem for p in CONTRACTS},
                         {"emcon", "safe-mode", "zeroize"})

    def test_contract_validates(self):
        self.assertTrue(CONTRACTS)
        for path in CONTRACTS:
            with self.subTest(contract=path.stem):
                doc = json.loads(path.read_text())
                check_schema(doc, SCHEMA)
                self.assertEqual(doc["machine"], path.stem)
                self.assertIn(doc["initial"], doc["states"])
                for t in doc["transitions"]:
                    self.assertIn(t["from"], doc["states"])
                    self.assertIn(t["to"], doc["states"])

    def test_schema_rejects_missing_field(self):
        # Runs with or without jsonschema (fallback enforces "required").
        for key in SCHEMA["required"]:
            with self.subTest(removed=key):
                doc = json.loads(CONTRACTS[0].read_text())
                del doc[key]
                with self.assertRaises(SchemaError):
                    check_schema(doc, SCHEMA)
        doc = json.loads(CONTRACTS[0].read_text())
        del doc["transitions"][0]["trigger"]
        with self.assertRaises(SchemaError):
            check_schema(doc, SCHEMA)

    def test_list_json(self):
        r = run(self.tmp_path, "list", "--json")
        self.assertEqual(r.returncode, 0)
        self.assertEqual(r.stdout,
                         '{"machines": ["emcon", "safe-mode", "zeroize"]}\n')

    def test_list_text(self):
        r = run(self.tmp_path, "list")
        self.assertIn("emcon", r.stdout)
        self.assertIn("zeroize", r.stdout)

    def test_flag_machines(self):
        for machine, rel, on in [
            ("emcon", "etc/aryaos/emcon", "on"),
            ("zeroize", "run/aryaos-zeroize.keep-network", "zeroizing"),
        ]:
            with self.subTest(machine=machine):
                with tempfile.TemporaryDirectory() as d:
                    off = "off" if machine == "emcon" else "normal"
                    self.assertEqual(status(d, machine),
                                     {"machine": machine, "state": off})
                    touch(d, rel)
                    self.assertEqual(status(d, machine),
                                     {"machine": machine, "state": on})

    def test_safe_mode_states(self):
        t = self.tmp_path
        self.assertEqual(status(t, "safe-mode")["state"], "normal")
        touch(t, "var/lib/aryaos/boot-attempts", "0\n")
        self.assertEqual(status(t, "safe-mode")["state"], "normal")
        touch(t, "var/lib/aryaos/boot-attempts", "2\n")
        self.assertEqual(status(t, "safe-mode")["state"], "counting")
        touch(t, "etc/aryaos/safe-mode")
        self.assertEqual(status(t, "safe-mode")["state"], "safe")

    def test_unreadable_counter_unknown_with_reason(self):
        touch(self.tmp_path, "var/lib/aryaos/boot-attempts", "garbage")
        d = status(self.tmp_path, "safe-mode")
        self.assertEqual(d["state"], "unknown")
        self.assertIn("boot-attempts", d["reason"])

    def test_source_is_directory_unknown(self):
        (self.tmp_path / "var/lib/aryaos/boot-attempts").mkdir(parents=True)
        d = status(self.tmp_path, "safe-mode")
        self.assertEqual(d["state"], "unknown")
        self.assertTrue(d["reason"])

    def test_flag_parent_not_directory_unknown(self):
        touch(self.tmp_path, "etc/aryaos", "i am a file")
        d = status(self.tmp_path, "emcon")
        self.assertEqual(d["state"], "unknown")
        self.assertIn("emcon", d["reason"])

    def test_missing_root_flag_is_inactive(self):
        # absent flag file = inactive state (by contract); no crash
        r = run(self.tmp_path / "nonexistent", "status", "emcon", "--json")
        self.assertEqual(r.returncode, 0)
        self.assertEqual(json.loads(r.stdout)["state"], "off")

    def test_json_stable(self):
        touch(self.tmp_path, "etc/aryaos/emcon")
        a = run(self.tmp_path, "status", "emcon", "--json").stdout
        b = run(self.tmp_path, "status", "emcon", "--json").stdout
        self.assertEqual(a, b)
        self.assertEqual(a, '{"machine": "emcon", "state": "on"}\n')

    def test_text_output(self):
        self.assertEqual(run(self.tmp_path, "status", "emcon").stdout,
                         "emcon: off\n")

    def test_unknown_machine_and_missing_arg(self):
        self.assertEqual(run(self.tmp_path, "status", "nope").returncode, 1)
        self.assertEqual(run(self.tmp_path, "status").returncode, 1)

    def test_read_only(self):
        touch(self.tmp_path, "etc/aryaos/emcon")
        before = sorted(str(p) for p in self.tmp_path.rglob("*"))
        run(self.tmp_path, "status", "emcon")
        run(self.tmp_path, "list")
        self.assertEqual(before, sorted(str(p) for p in self.tmp_path.rglob("*")))


    def _install_cli(self, with_contracts):
        sbin = self.tmp_path / "usr" / "local" / "sbin"
        sbin.mkdir(parents=True)
        cli = sbin / "aryaos-state"
        shutil.copy2(CLI, cli)
        share = self.tmp_path / "share"
        if with_contracts:
            shutil.copytree(STATE_DIR, share)
        return cli, share

    def test_installed_layout(self):
        cli, share = self._install_cli(True)
        env = {"PATH": "/usr/bin:/bin", "ARYAOS_STATE_CONTRACTS": str(share)}
        r = subprocess.run([sys.executable, str(cli), "list", "--json"],
                           env=env, capture_output=True, text=True, timeout=30)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(json.loads(r.stdout)["machines"],
                         ["emcon", "safe-mode", "zeroize"])

    def test_no_contracts_dir_clean_error(self):
        cli, share = self._install_cli(False)
        env = {"PATH": "/usr/bin:/bin",
               "ARYAOS_STATE_CONTRACTS": str(share)}
        r = subprocess.run([sys.executable, str(cli), "list"],
                           env=env, capture_output=True, text=True, timeout=30)
        self.assertEqual(r.returncode, 1)
        self.assertNotIn("Traceback", r.stderr)
        self.assertIn(str(share), r.stderr)
        self.assertIn("/usr/share/aryaos/state", r.stderr)
        self.assertIn(str(cli.parent / "state"), r.stderr)


if __name__ == "__main__":
    unittest.main()
