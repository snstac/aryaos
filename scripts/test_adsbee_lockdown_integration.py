#!/usr/bin/env python3
import os
import pty
import subprocess
import tempfile
import unittest
import threading
import time
from pathlib import Path

class LockdownIntegrationTest(unittest.TestCase):
    def setUp(self):
        self.master_fd, self.slave_fd = pty.openpty()
        self.slave_name = os.ttyname(self.slave_fd)
        self.config_dir = tempfile.TemporaryDirectory()
        self.config_path = Path(self.config_dir.name) / "aryaos-config.txt"
        self.config_path.write_text(f"ARYAOS_ADSB_1090_SOURCE=adsbee\nARYAOS_ADSB_1090_DEVICE={self.slave_name}")

    def tearDown(self):
        os.close(self.master_fd)
        os.close(self.slave_fd)
        self.config_dir.cleanup()

    def test_save_failure_exits_nonzero(self):
        # Thread to handle the fake ADSBee console
        def fake_adsbee():
            # 1. Response to AT+SETTINGS?DUMP
            # The script reads until timeout. We'll send the dump and then stop.
            # But we need to send it when the script asks for it.
            while True:
                try:
                    data = os.read(self.master_fd, 4096).decode("latin-1")
                    if not data: break
                    if "AT+SETTINGS?DUMP" in data:
                        os.write(self.master_fd, b"AT+WIFI_AP=1,ADSBee1090-9A3B7C,yummyflowers,1\\r\\nAT+WIFI_STA=0,,\\r\\nAT+ETHERNET=1\\r\\nAT+ESP32_ENABLE=1\\r\\nAT+LOG_LEVEL=INFO\\r\\nAT+PROTOCOL_OUT=CONSOLE,NONE\\r\\nAT+PROTOCOL_OUT=COMMS_UART,NONE\\r\\nAT+FEED=6,feed.whereplane.xyz,0,1,RAW\\r\\nAT+FEED=9,feed.adsb.fi,0,1,RAW\\r\\n")
                    elif "AT+SETTINGS=SAVE" in data:
                        os.write(self.master_fd, b"ERROR: Flash write failed\\r\\n")
                        break # Done after save
                    else:
                        os.write(self.master_fd, b"OK\\r\\n")
                except OSError:
                    break

        t = threading.Thread(target=fake_adsbee, daemon=True)
        t.start()

        env = os.environ.copy()
        env["ARYAOS_CONFIG_PATH"] = str(self.config_path)
        script_path = "/home/hermes/devops/wt/t_91bbb65c/aryaos/shared_files/adsbcot/aryaos-adsbee-lockdown"
        
        result = subprocess.run(["python3", script_path], env=env, capture_output=True, text=True)
        
        self.assertEqual(result.returncode, 1)
        self.assertIn("ERROR: Flash write failed", result.stderr)
        self.assertIn("aryaos-adsbee-lockdown", result.stderr)

    def test_success_flow(self):
        def fake_adsbee_success():
            while True:
                try:
                    data = os.read(self.master_fd, 4096).decode("latin-1")
                    if not data: break
                    if "AT+SETTINGS?DUMP" in data:
                        os.write(self.master_fd, b"AT+WIFI_AP=1,ADSBee1090-9A3B7C,yummyflowers,1\\r\\nAT+WIFI_STA=0,,\\r\\nAT+ETHERNET=1\\r\\nAT+ESP32_ENABLE=1\\r\\nAT+LOG_LEVEL=INFO\\r\\nAT+PROTOCOL_OUT=CONSOLE,NONE\\r\\nAT+PROTOCOL_OUT=COMMS_UART,NONE\\r\\nAT+FEED=6,feed.whereplane.xyz,0,1,RAW\\r\\nAT+FEED=9,feed.adsb.fi,0,1,RAW\\r\\n")
                    elif "AT+SETTINGS=SAVE" in data:
                        os.write(self.master_fd, b"OK\\r\\n")
                        break
                    else:
                        os.write(self.master_fd, b"OK\\r\\n")
                except OSError:
                    break

        t = threading.Thread(target=fake_adsbee_success, daemon=True)
        t.start()

        env = os.environ.copy()
        env["ARYAOS_CONFIG_PATH"] = str(self.config_path)
        script_path = "/home/hermes/devops/wt/t_91bbb65c/aryaos/shared_files/adsbcot/aryaos-adsbee-lockdown"
        
        result = subprocess.run(["python3", script_path], env=env, capture_output=True, text=True)
        
        self.assertEqual(result.returncode, 0)
        self.assertIn("applied", result.stderr)
        self.assertIn("saved to nonvolatile memory", result.stderr)

if __name__ == "__main__":
    unittest.main()
