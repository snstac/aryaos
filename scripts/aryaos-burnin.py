#!/usr/bin/env python3
"""Sample AryaOS fleet health during unattended burn-in runs."""

from __future__ import annotations

import argparse
import concurrent.futures
import datetime as dt
import json
import os
import signal
import subprocess
import sys
import time
from pathlib import Path


REMOTE_PROBE = r'''
import glob, json, os, subprocess, time
from pathlib import Path

SERVICES = (
    "charontak", "lincot", "dronecot", "dronecot-wifi",
    "dronecot-dronescout", "acarscot", "acarsdec", "readsb",
    "adsbcot", "aiscot", "gutcheck", "aryaos-neighbord",
    "aryaos-bt-pan", "cockpit.socket",
)

def read(path, default=""):
    try:
        return open(path, encoding="utf-8", errors="replace").read().strip()
    except OSError:
        return default

def run(args, timeout=5):
    try:
        p = subprocess.run(args, capture_output=True, text=True, timeout=timeout)
        return p.returncode, (p.stdout or "").strip(), (p.stderr or "").strip()
    except (OSError, subprocess.TimeoutExpired) as exc:
        return 124, "", str(exc)

def number(value, divisor=1.0):
    try:
        return round(float(value) / divisor, 3)
    except (TypeError, ValueError):
        return None

def memory():
    vals = {}
    for line in read("/proc/meminfo").splitlines():
        parts = line.replace(":", "").split()
        if len(parts) >= 2 and parts[1].isdigit():
            vals[parts[0]] = int(parts[1])
    total, available = vals.get("MemTotal", 0), vals.get("MemAvailable", 0)
    return {
        "total_kib": total,
        "available_kib": available,
        "used_pct": round((total - available) * 100 / total, 2) if total else None,
        "swap_used_kib": vals.get("SwapTotal", 0) - vals.get("SwapFree", 0),
    }

def services():
    result = {}
    props = ("LoadState", "ActiveState", "SubState", "MainPID", "NRestarts",
             "ExecMainStatus", "CPUUsageNSec", "MemoryCurrent")
    for name in SERVICES:
        rc, out, err = run(["systemctl", "show", name, "--no-pager", "--property=" + ",".join(props)])
        values = {}
        for line in out.splitlines():
            key, sep, value = line.partition("=")
            if sep:
                values[key] = value
        if values.get("LoadState") != "not-found":
            for key in ("MainPID", "NRestarts", "ExecMainStatus", "CPUUsageNSec", "MemoryCurrent"):
                if str(values.get(key, "")).isdigit():
                    values[key] = int(values[key])
            result[name] = values or {"probe_rc": rc, "error": err}
    return result

def gateway_status():
    result = {}
    for path in glob.glob("/run/*/status.json"):
        try:
            doc = json.loads(read(path))
        except (TypeError, ValueError):
            continue
        app = Path(path).parent.name
        result[app] = {
            "wall_t": doc.get("wall_t"), "uptime_s": doc.get("uptime_s"),
            "tracked": doc.get("tracked"), "counters": doc.get("counters") or {},
            "trend": (doc.get("trend") or [])[-5:],
            "write_errors": doc.get("write_errors"),
        }
    return result

def networks():
    result = {}
    for path in glob.glob("/sys/class/net/*"):
        name = os.path.basename(path)
        stats = {}
        for key in ("rx_bytes", "tx_bytes", "rx_packets", "tx_packets",
                    "rx_errors", "tx_errors", "rx_dropped", "tx_dropped"):
            value = read(f"{path}/statistics/{key}")
            stats[key] = int(value) if value.isdigit() else None
        stats["operstate"] = read(f"{path}/operstate")
        result[name] = stats
    return result

load = read("/proc/loadavg").split()
stat = os.statvfs("/")
disk_total = stat.f_blocks * stat.f_frsize
disk_free = stat.f_bavail * stat.f_frsize
rc, throttled, _ = run(["vcgencmd", "get_throttled"])
failed_rc, failed, failed_err = run(["systemctl", "--failed", "--no-legend", "--plain"])
jrc, journal_warnings, jerr = run(
    ["journalctl", "-p", "warning", "--since", "-2 minutes", "--no-pager", "-o", "cat"], 8
)
_, usb, _ = run(["lsusb"])
_, top, _ = run(["ps", "-eo", "pid,etimes,%cpu,%mem,rss,comm", "--sort=-%cpu"])
health = {}
if os.path.exists("/usr/local/sbin/aryaos-antsdr-health"):
    rc, out, err = run(["/usr/local/sbin/aryaos-antsdr-health", "--quiet", "--json"])
    try:
        health["antsdr"] = json.loads(out)
    except ValueError:
        health["antsdr"] = {"probe_rc": rc, "error": err or out}
try:
    import urllib.request
    with urllib.request.urlopen("http://127.0.0.1:8181/healthz", timeout=2) as response:
        health["gutcheck"] = {"http": response.status, "body": response.read(200).decode()}
except Exception as exc:
    health["gutcheck"] = {"unavailable": type(exc).__name__}

print(json.dumps({
    "remote_epoch": time.time(), "hostname": os.uname().nodename,
    "boot_id": read("/proc/sys/kernel/random/boot_id"),
    "uptime_s": number(read("/proc/uptime").split()[0] if read("/proc/uptime") else None),
    "load": [number(x) for x in load[:3]],
    "temperature_c": number(read("/sys/class/thermal/thermal_zone0/temp"), 1000),
    "cpu_freq_mhz": number(read("/sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq"), 1000),
    "throttled": throttled if rc == 0 else None,
    "memory": memory(),
    "disk": {"total_bytes": disk_total, "free_bytes": disk_free,
             "used_pct": round((disk_total - disk_free) * 100 / disk_total, 2)},
    "failed_units": failed.splitlines() if failed_rc in (0, 1) else [failed_err],
    "journal_warning_count_2m": len([x for x in journal_warnings.splitlines() if x.strip()]),
    "journal_warning_tail": journal_warnings.splitlines()[-12:],
    "services": services(), "gateway_status": gateway_status(),
    "networks": networks(), "usb": usb.splitlines(), "health": health,
    "top_processes": top.splitlines()[1:13],
}, separators=(",", ":")))
'''


STOP = False


def stop(_signum, _frame):
    global STOP
    STOP = True


def probe(host, args):
    cmd = [
        "ssh", "-i", args.key, "-o", "BatchMode=yes", "-o", "IdentitiesOnly=yes",
        "-o", "ConnectTimeout=12", "-o", "StrictHostKeyChecking=yes",
        "-o", f"UserKnownHostsFile={args.known_hosts}", f"{args.user}@{host}",
        "sudo", "-n", "python3", "-",
    ]
    started = time.monotonic()
    try:
        proc = subprocess.run(
            cmd, input=REMOTE_PROBE, text=True, capture_output=True, timeout=args.probe_timeout
        )
    except subprocess.TimeoutExpired as exc:
        return {"host": host, "ok": False, "error": f"probe timeout: {exc}", "duration_s": args.probe_timeout}
    sample = {"host": host, "ok": proc.returncode == 0, "duration_s": round(time.monotonic() - started, 3)}
    if proc.returncode == 0:
        try:
            sample.update(json.loads(proc.stdout))
        except ValueError as exc:
            sample.update(ok=False, error=f"invalid JSON: {exc}", stdout=proc.stdout[-1000:])
    else:
        sample.update(error=proc.stderr[-2000:], stdout=proc.stdout[-1000:])
    return sample


def summarize(samples):
    summary = {"sample_count": len(samples), "hosts": {}}
    for sample in samples:
        host = sample["host"]
        out = summary["hosts"].setdefault(host, {
            "samples": 0, "probe_failures": 0, "max_temp_c": None, "max_load1": None,
            "max_mem_pct": None, "max_disk_pct": None, "throttle_events": 0,
            "failed_units": [], "service_nonactive": {}, "restart_range": {},
            "service_state_counts": {}, "journal_warnings": 0, "boot_ids": [],
            "first_mem_pct": None, "last_mem_pct": None, "mem_delta_pct": None,
        })
        out["samples"] += 1
        if not sample.get("ok"):
            out["probe_failures"] += 1
            continue
        for key, value in (("max_temp_c", sample.get("temperature_c")),
                           ("max_load1", (sample.get("load") or [None])[0]),
                           ("max_mem_pct", (sample.get("memory") or {}).get("used_pct")),
                           ("max_disk_pct", (sample.get("disk") or {}).get("used_pct"))):
            if value is not None:
                out[key] = value if out[key] is None else max(out[key], value)
        mem_pct = (sample.get("memory") or {}).get("used_pct")
        if mem_pct is not None:
            if out["first_mem_pct"] is None:
                out["first_mem_pct"] = mem_pct
            out["last_mem_pct"] = mem_pct
            out["mem_delta_pct"] = round(
                out["last_mem_pct"] - out["first_mem_pct"], 2
            )
        if sample.get("throttled") not in (None, "throttled=0x0"):
            out["throttle_events"] += 1
        out["journal_warnings"] += sample.get("journal_warning_count_2m") or 0
        out["failed_units"] = sorted(set(out["failed_units"] + sample.get("failed_units", [])))
        boot_id = sample.get("boot_id")
        if boot_id and boot_id not in out["boot_ids"]:
            out["boot_ids"].append(boot_id)
        for name, state in (sample.get("services") or {}).items():
            active_state = state.get("ActiveState") or "unknown"
            counts = out["service_state_counts"].setdefault(name, {})
            counts[active_state] = counts.get(active_state, 0) + 1
            if active_state not in ("active", "inactive"):
                out["service_nonactive"][name] = out["service_nonactive"].get(name, 0) + 1
            restarts = state.get("NRestarts")
            if isinstance(restarts, int):
                limits = out["restart_range"].setdefault(name, [restarts, restarts])
                limits[0], limits[1] = min(limits[0], restarts), max(limits[1], restarts)
    # Optional services are legitimately inactive for the whole run. Flag an
    # inactive sample only when that same service was observed active elsewhere
    # in the run: that is a role service dropping out, not an unused package.
    for out in summary["hosts"].values():
        for name, counts in out["service_state_counts"].items():
            inactive = counts.get("inactive", 0)
            if counts.get("active", 0) and inactive:
                out["service_nonactive"][name] = (
                    out["service_nonactive"].get(name, 0) + inactive
                )
    return summary


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--hosts", nargs="+", default=["192.168.0.13", "192.168.0.44", "192.168.0.60", "192.168.0.199"])
    parser.add_argument("--user", default="pi")
    parser.add_argument("--key", default="shared_files/aryaos/ssh/aryaos-dev-lab")
    parser.add_argument("--known-hosts", default="/tmp/aryaos-burnin-known-hosts")
    parser.add_argument("--duration-hours", type=float, default=8.0)
    parser.add_argument("--duration-seconds", type=float)
    parser.add_argument("--interval", type=float, default=60.0)
    parser.add_argument("--probe-timeout", type=float, default=30.0)
    parser.add_argument("--output")
    args = parser.parse_args()
    duration = args.duration_seconds if args.duration_seconds is not None else args.duration_hours * 3600
    stamp = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    output = Path(args.output or f".aryaos-burnin/{stamp}")
    output.mkdir(parents=True, exist_ok=False)
    (output / "metadata.json").write_text(json.dumps({
        "started_utc": stamp, "duration_s": duration, "interval_s": args.interval,
        "hosts": args.hosts, "argv": sys.argv,
    }, indent=2) + "\n")
    samples = []
    deadline = time.monotonic() + duration
    cycle = 0
    with (output / "samples.jsonl").open("a", buffering=1) as stream:
        while not STOP and time.monotonic() < deadline:
            cycle += 1
            cycle_started = time.monotonic()
            captured = dt.datetime.now(dt.timezone.utc).isoformat()
            with concurrent.futures.ThreadPoolExecutor(max_workers=len(args.hosts)) as pool:
                batch = list(pool.map(lambda host: probe(host, args), args.hosts))
            for sample in batch:
                sample["captured_utc"] = captured
                sample["cycle"] = cycle
                samples.append(sample)
                stream.write(json.dumps(sample, separators=(",", ":")) + "\n")
            states = ", ".join(
                f"{s['host']}={'ok' if s.get('ok') else 'FAIL'}"
                + (f" {s.get('temperature_c')}C" if s.get("temperature_c") is not None else "")
                for s in batch
            )
            print(f"{captured} cycle={cycle} {states}", flush=True)
            wait = min(args.interval - (time.monotonic() - cycle_started), deadline - time.monotonic())
            if wait > 0 and not STOP:
                time.sleep(wait)
    result = summarize(samples)
    result["finished_utc"] = dt.datetime.now(dt.timezone.utc).isoformat()
    (output / "summary.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({"output": str(output), **result}, indent=2), flush=True)
    return 0


if __name__ == "__main__":
    signal.signal(signal.SIGINT, stop)
    signal.signal(signal.SIGTERM, stop)
    raise SystemExit(main())
