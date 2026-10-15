import json
import os
from pathlib import Path
import socket
import tempfile
import threading
import unittest
from unittest.mock import patch

from tray import DaemonClient, receivers, summary


class DaemonClientTests(unittest.TestCase):
    def exchange(self, reply, command="status", **fields):
        with tempfile.TemporaryDirectory() as directory:
            path = str(Path(directory) / "daemon.sock")
            server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            server.bind(path)
            server.listen(1)
            requests = []

            def serve():
                with server, server.accept()[0] as connection:
                    with connection.makefile("rb") as reader:
                        requests.append(json.loads(reader.readline()))
                    connection.sendall(reply)

            worker = threading.Thread(target=serve)
            worker.start()
            try:
                response = DaemonClient(path).request(command, **fields)
            finally:
                worker.join(timeout=5)
            self.assertFalse(worker.is_alive())
            return response, requests

    def test_request_is_newline_delimited_and_keeps_ip_separate_from_port(self):
        response, requests = self.exchange(
            b'{"ok":true,"state":"connecting"}\n',
            "connect", target="10.0.60.19", port=7100,
        )
        self.assertEqual(requests, [{"cmd": "connect", "target": "10.0.60.19", "port": 7100}])
        self.assertEqual(response["state"], "connecting")

    def test_password_is_sent_over_socket_without_trimming(self):
        _, requests = self.exchange(
            b'{"ok":true}\n', "connect", target="10.0.60.19", pin=" a long password ",
        )
        self.assertEqual(requests[0]["pin"], " a long password ")

    def test_daemon_rejection(self):
        with self.assertRaisesRegex(ValueError, "already connected"):
            self.exchange(b'{"ok":false,"error":"already connected"}\n')

    def test_incomplete_response(self):
        with self.assertRaisesRegex(ValueError, "Incomplete response"):
            self.exchange(b'{"ok":true}')

    def test_invalid_json(self):
        with self.assertRaises(ValueError):
            self.exchange(b'broken\n')

    def test_missing_daemon(self):
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaises(OSError):
                DaemonClient(str(Path(directory) / "missing.sock")).request("status")

    def test_socket_path_matches_daemon(self):
        with patch.dict(os.environ, {"XDG_RUNTIME_DIR": "/run/user/1000"}):
            self.assertEqual(DaemonClient().path, "/run/user/1000/doubletake.sock")
        with patch.dict(os.environ, {}, clear=True):
            self.assertEqual(DaemonClient().path, "/tmp/doubletake.sock")

    def test_snapshot_reads_status_and_cached_discovery(self):
        client = DaemonClient()
        status = {"ok": True, "streams": []}
        with patch.object(client, "request", side_effect=[status, {"ok": True, "devices": None}]) as request:
            self.assertEqual(client.snapshot(), (status, []))
        self.assertEqual([call.args for call in request.call_args_list], [("status",), ("discover",)])


class ReceiverTests(unittest.TestCase):
    def test_sorted_receivers_preserve_nonstandard_port(self):
        rows = receivers({}, [
            {"name": "Office", "ip": "10.0.60.20", "port": 7100},
            {"name": "Living Room", "ip": "10.0.60.19", "port": 7000},
        ])
        self.assertEqual([row["name"] for row in rows], ["Living Room", "Office"])
        self.assertEqual(rows[1]["port"], 7100)
        self.assertEqual(rows[0]["state"], "idle")

    def test_duplicate_discovery_and_active_stream_are_merged_by_ip(self):
        device = {"name": "TV", "ip": "10.0.60.19", "port": 7100}
        status = {"streams": [{
            "device": "TV", "device_ip": "10.0.60.19", "state": "streaming",
            "has_audio": True, "audio_muted": True,
        }]}
        rows = receivers(status, [device, device])
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]["port"], 7100)
        self.assertTrue(rows[0]["audio_muted"])

    def test_active_receiver_remains_when_discovery_expires(self):
        rows = receivers({"streams": [{
            "device": "TV", "device_ip": "10.0.60.19", "state": "pin_required",
            "credential_kind": "password",
        }]}, [])
        self.assertEqual(rows[0]["name"], "TV")
        self.assertEqual(rows[0]["credential_kind"], "password")

    def test_empty_or_null_streams(self):
        self.assertEqual(receivers({"streams": None}, []), [])
        self.assertEqual(summary({}), "Choose an AirPlay receiver")

    def test_connect_is_not_reported_as_streaming(self):
        self.assertEqual(summary({"streams": [{"state": "connecting"}]}), "Connecting…")
        self.assertEqual(summary({"streams": [{"state": "pin_required"}]}), "Pairing required")

    def test_multi_receiver_summary(self):
        self.assertEqual(summary({"streams": [{"state": "streaming"}]}), "Mirroring to 1 receiver")
        self.assertEqual(summary({"streams": [{"state": "streaming"}] * 2}), "Mirroring to 2 receivers")


if __name__ == "__main__":
    unittest.main()
