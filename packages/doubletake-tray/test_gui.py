import copy
import os
import unittest

from tray import create_application


class FakeDaemon:
    def __init__(self):
        self.status = {"ok": True, "state": "idle", "streams": []}
        self.devices = [{"name": "Living Room", "ip": "10.0.60.19", "port": 7100}]
        self.requests = []

    def snapshot(self):
        return copy.deepcopy((self.status, self.devices))

    def request(self, command, **fields):
        self.requests.append({"cmd": command, **fields})
        ip = fields.get("target")
        if command == "connect":
            state = "streaming" if "pin" in fields else "connecting"
            self.status["streams"] = [{"device": "Living Room", "device_ip": ip, "state": state}]
        elif command == "disconnect":
            self.status["streams"] = [stream for stream in self.status["streams"] if ip and stream["device_ip"] != ip]
        elif command in ("mute", "unmute"):
            for stream in self.status["streams"]:
                if stream["device_ip"] == ip:
                    stream["audio_muted"] = command == "mute"
        return copy.deepcopy(self.status)


class FakeIndicator:
    def set_menu(self, menu):
        self.menu = menu

    def set_icon_full(self, icon, description):
        self.icon = icon


@unittest.skipUnless(os.environ.get("DOUBLETAKE_TRAY_GUI_TESTS"), "requires GTK display")
class TrayTests(unittest.TestCase):
    def setUp(self):
        self.app = create_application()
        self.app.client = FakeDaemon()
        self.app.indicator = FakeIndicator()
        self.notifications = []
        self.app.notify = self.notifications.append
        self.app.submit = lambda operation, callback: callback(operation(), None)
        self.app.poll()

    def tearDown(self):
        for dialog in list(self.app.dialogs.values()):
            dialog.destroy()
        self.app.executor.shutdown(wait=True)

    def item(self, label, menu=None):
        menu = menu or self.app.indicator.menu
        return next(item for item in menu.get_children() if item.get_label() == label)

    def wait_for_credential(self, kind):
        self.app.client.status["streams"] = [{
            "device": "Living Room", "device_ip": "10.0.60.19",
            "state": "pin_required", "credential_kind": kind,
        }]
        self.app.poll()
        return self.app.dialogs["10.0.60.19"]

    def entry(self, dialog):
        from gi.repository import Gtk
        return next(widget for widget in dialog.get_content_area().get_children() if isinstance(widget, Gtk.Entry))

    def test_discovered_receiver_connects_with_advertised_port(self):
        self.item("Living Room (10.0.60.19)").activate()
        self.assertEqual(self.app.client.requests, [{"cmd": "connect", "target": "10.0.60.19", "port": 7100}])
        self.item("Living Room (10.0.60.19) — Connecting…")
        self.assertEqual(self.app.indicator.icon, "video-display-symbolic")

    def test_pairing_prompts_once_and_submits_over_socket(self):
        from gi.repository import Gtk
        dialog = self.wait_for_credential("pin")
        self.app.poll()
        self.assertIs(self.app.dialogs["10.0.60.19"], dialog)
        self.entry(dialog).set_text("1234")
        dialog.response(Gtk.ResponseType.OK)
        self.assertEqual(self.app.client.requests[-1], {"cmd": "connect", "target": "10.0.60.19", "pin": "1234"})
        self.assertFalse(self.app.dialogs)
        self.assertEqual(self.app.indicator.icon, "network-transmit-receive-symbolic")

    def test_password_prompt_is_hidden_and_preserves_spaces(self):
        from gi.repository import Gtk
        dialog = self.wait_for_credential("password")
        entry = self.entry(dialog)
        self.assertFalse(entry.get_visibility())
        entry.set_text(" long password ")
        dialog.response(Gtk.ResponseType.OK)
        self.assertEqual(self.app.client.requests[-1]["pin"], " long password ")

    def test_cancel_pairing_disconnects_target(self):
        from gi.repository import Gtk
        self.wait_for_credential("pin").response(Gtk.ResponseType.CANCEL)
        self.assertEqual(self.app.client.requests[-1], {"cmd": "disconnect", "target": "10.0.60.19"})
        self.assertFalse(self.app.dialogs)

    def test_external_disconnect_closes_stale_dialog(self):
        self.wait_for_credential("pin")
        self.app.client.status["streams"] = []
        self.app.poll()
        self.assertFalse(self.app.dialogs)

    def test_per_receiver_mute_and_stop(self):
        self.app.client.status["streams"] = [{
            "device": "Living Room", "device_ip": "10.0.60.19", "state": "streaming",
            "has_audio": True, "audio_muted": False,
        }]
        self.app.poll()
        label = "Living Room (10.0.60.19) — Mirroring"
        self.item("Mute", self.item(label).get_submenu()).activate()
        self.assertEqual(self.app.client.requests[-1], {"cmd": "mute", "target": "10.0.60.19"})
        self.item("Unmute", self.item(label).get_submenu())
        self.item("Stop", self.item(label).get_submenu()).activate()
        self.assertEqual(self.app.client.requests[-1], {"cmd": "disconnect", "target": "10.0.60.19"})

    def test_daemon_failure_removes_stale_controls(self):
        self.wait_for_credential("pin")
        self.app.received(None, "Connection refused")
        self.assertFalse(self.app.dialogs)
        self.item("Daemon unavailable: Connection refused")
        self.assertEqual(self.app.indicator.icon, "video-display-symbolic")

    def test_unchanged_poll_preserves_open_menu(self):
        menu = self.app.indicator.menu
        self.app.poll()
        self.assertIs(self.app.indicator.menu, menu)

    def test_asynchronous_error_is_notified_once(self):
        self.app.client.status["error"] = "SETUP rejected"
        self.app.poll()
        self.app.poll()
        self.assertEqual(self.notifications, ["SETUP rejected"])


if __name__ == "__main__":
    unittest.main()
