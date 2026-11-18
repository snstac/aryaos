"""Tests for shared_files/aryaos/aryaos-state (ASM-04). Stdlib + pytest."""
import json
import os
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent / "shared_files" / "aryaos"
CLI = ROOT / "aryaos-state"
STATE_DIR = ROOT / "state"
CONTRACTS = sorted(p for p in STATE_DIR.glob("*.json") if p.name != "schema.json")
SCHEMA = json.loads((STATE_DIR / "schema.json").read_text())


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


def check_schema(doc, schema):
    try:
        import jsonschema
    except ImportError:
        for k in schema["required"]:
            assert k in doc
        return
    jsonschema.validate(doc, schema)


def test_three_contracts_present():
    assert {p.stem for p in CONTRACTS} == {"emcon", "safe-mode", "zeroize"}


@pytest.mark.parametrize("path", CONTRACTS, ids=lambda p: p.stem)
def test_contract_validates(path):
    doc = json.loads(path.read_text())
    check_schema(doc, SCHEMA)
    assert doc["machine"] == path.stem
    assert doc["initial"] in doc["states"]
    for t in doc["transitions"]:
        assert t["from"] in doc["states"] and t["to"] in doc["states"]


def test_schema_rejects_missing_field():
    pytest.importorskip("jsonschema")
    import jsonschema
    doc = json.loads(CONTRACTS[0].read_text())
    del doc["transitions"]
    with pytest.raises(jsonschema.ValidationError):
        jsonschema.validate(doc, SCHEMA)


def test_list_json(tmp_path):
    r = run(tmp_path, "list", "--json")
    assert r.returncode == 0
    assert r.stdout == '{"machines": ["emcon", "safe-mode", "zeroize"]}\n'


def test_list_text(tmp_path):
    r = run(tmp_path, "list")
    assert "emcon" in r.stdout and "zeroize" in r.stdout


@pytest.mark.parametrize("machine,rel,on", [
    ("emcon", "etc/aryaos/emcon", "on"),
    ("zeroize", "run/aryaos-zeroize.keep-network", "zeroizing"),
])
def test_flag_machines(tmp_path, machine, rel, on):
    off = "off" if machine == "emcon" else "normal"
    assert status(tmp_path, machine) == {"machine": machine, "state": off}
    touch(tmp_path, rel)
    assert status(tmp_path, machine) == {"machine": machine, "state": on}


def test_safe_mode_states(tmp_path):
    assert status(tmp_path, "safe-mode")["state"] == "normal"
    touch(tmp_path, "var/lib/aryaos/boot-attempts", "0\n")
    assert status(tmp_path, "safe-mode")["state"] == "normal"
    touch(tmp_path, "var/lib/aryaos/boot-attempts", "2\n")
    assert status(tmp_path, "safe-mode")["state"] == "counting"
    touch(tmp_path, "etc/aryaos/safe-mode")
    assert status(tmp_path, "safe-mode")["state"] == "safe"


def test_unreadable_counter_unknown_with_reason(tmp_path):
    touch(tmp_path, "var/lib/aryaos/boot-attempts", "garbage")
    d = status(tmp_path, "safe-mode")
    assert d["state"] == "unknown" and "boot-attempts" in d["reason"]


def test_source_is_directory_unknown(tmp_path):
    (tmp_path / "var/lib/aryaos/boot-attempts").mkdir(parents=True)
    d = status(tmp_path, "safe-mode")
    assert d["state"] == "unknown" and d["reason"]


def test_flag_parent_not_directory_unknown(tmp_path):
    touch(tmp_path, "etc/aryaos", "i am a file")
    d = status(tmp_path, "emcon")
    assert d["state"] == "unknown" and "emcon" in d["reason"]


def test_missing_root_flag_is_inactive(tmp_path):
    # absent flag file = inactive state (by contract); no crash
    r = run(tmp_path / "nonexistent", "status", "emcon", "--json")
    assert r.returncode == 0 and json.loads(r.stdout)["state"] == "off"


def test_json_stable(tmp_path):
    touch(tmp_path, "etc/aryaos/emcon")
    a = run(tmp_path, "status", "emcon", "--json").stdout
    b = run(tmp_path, "status", "emcon", "--json").stdout
    assert a == b == '{"machine": "emcon", "state": "on"}\n'


def test_text_output(tmp_path):
    assert run(tmp_path, "status", "emcon").stdout == "emcon: off\n"


def test_unknown_machine_and_missing_arg(tmp_path):
    assert run(tmp_path, "status", "nope").returncode == 1
    assert run(tmp_path, "status").returncode == 1


def test_read_only(tmp_path):
    touch(tmp_path, "etc/aryaos/emcon")
    before = sorted(str(p) for p in tmp_path.rglob("*"))
    run(tmp_path, "status", "emcon")
    run(tmp_path, "list")
    assert before == sorted(str(p) for p in tmp_path.rglob("*"))
