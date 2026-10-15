import concurrent.futures
import json
import logging
import os
from pathlib import Path
import signal
import socket
import sys


class DaemonClient:
    def __init__(self, path=None):
        self.path = path or str(Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / "doubletake.sock")

    def request(self, command, **fields):
        payload = {"cmd": command, **fields}
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as connection:
            connection.settimeout(3)
            connection.connect(self.path)
            connection.sendall(json.dumps(payload).encode() + b"\n")
            with connection.makefile("rb") as reader:
                line = reader.readline(1024 * 1024)
        if not line.endswith(b"\n"):
            raise ValueError("Incomplete response from doubletake daemon")
        response = json.loads(line)
        if not response.get("ok"):
            raise ValueError(response.get("error") or "Doubletake rejected the request")
        return response

    def snapshot(self):
        status = self.request("status")
        devices = self.request("discover").get("devices") or []
        return status, devices


def receivers(status, devices):
    rows = {
        device["ip"]: {
            "ip": device["ip"],
            "name": device.get("name") or device["ip"],
            "port": device.get("port") or 7000,
            "state": "idle",
        }
        for device in devices
    }
    for stream in status.get("streams") or []:
        ip = stream["device_ip"]
        row = rows.setdefault(ip, {"ip": ip, "name": ip, "port": 7000})
        row.update(stream)
        row["name"] = stream.get("device") or row["name"]
    return sorted(rows.values(), key=lambda row: (row["name"].casefold(), row["ip"]))


def summary(status):
    streams = status.get("streams") or []
    streaming = sum(stream["state"] == "streaming" for stream in streams)
    if streaming:
        return f"Mirroring to {streaming} receiver{'s' if streaming != 1 else ''}"
    if any(stream["state"] == "pin_required" for stream in streams):
        return "Pairing required"
    if streams:
        return "Connecting…"
    return "Choose an AirPlay receiver"


def create_application():
    import gi

    gi.require_version("Gtk", "3.0")
    gi.require_version("AyatanaAppIndicator3", "0.1")
    gi.require_version("GLibUnix", "2.0")
    from gi.repository import AyatanaAppIndicator3 as AppIndicator, Gio, GLib, GLibUnix, Gtk

    class Tray(Gtk.Application):
        def __init__(self):
            super().__init__(application_id="io.reichard.DoubletakeTray")
            self.client = DaemonClient()
            self.executor = concurrent.futures.ThreadPoolExecutor(max_workers=1)
            self.indicator = None
            self.polling = False
            self.closing = False
            self.timer = None
            self.last_view = None
            self.status = {}
            self.devices = []
            self.dialogs = {}
            self.submitting = set()
            self.action_error = ""
            self.last_daemon_error = ""

        def do_activate(self):
            if self.indicator is None:
                self.hold()
                self.indicator = AppIndicator.Indicator.new(
                    "doubletake-tray", "video-display-symbolic", AppIndicator.IndicatorCategory.APPLICATION_STATUS
                )
                self.indicator.set_title("Doubletake")
                self.indicator.set_status(AppIndicator.IndicatorStatus.ACTIVE)
                self.render("Connecting to doubletake daemon…")
                self.timer = GLib.timeout_add_seconds(2, self.poll)
                for number in (signal.SIGTERM, signal.SIGINT):
                    GLibUnix.signal_add(GLib.PRIORITY_DEFAULT, number, self.quit_tray)
            self.poll()

        def submit(self, operation, callback):
            future = self.executor.submit(operation)

            def complete(result):
                try:
                    value, error = result.result(), None
                except Exception as exception:
                    value, error = None, str(exception)
                GLib.idle_add(callback, value, error)

            future.add_done_callback(complete)

        def poll(self):
            if not self.polling and not self.closing:
                self.polling = True
                self.submit(self.client.snapshot, self.received)
            return not self.closing

        def received(self, snapshot, error):
            self.polling = False
            if self.closing:
                return
            if error:
                self.status, self.devices = {}, []
                self.update_dialogs([])
                self.render(f"Daemon unavailable: {error}")
                return
            self.status, self.devices = snapshot
            daemon_error = self.status.get("error", "")
            if daemon_error and daemon_error != self.last_daemon_error:
                self.notify(daemon_error)
            self.last_daemon_error = daemon_error
            self.render(self.action_error or daemon_error)
            self.update_dialogs(receivers(self.status, self.devices))

        def action(self, command, **fields):
            self.action_error = ""
            self.submit(lambda: self.client.request(command, **fields), self.action_done)

        def action_done(self, response, error):
            if self.closing:
                return
            if error:
                self.submitting.clear()
                self.action_error = error
                self.notify(error)
                self.render(error)
            self.last_view = None
            self.poll()

        def notify(self, message):
            logging.error("%s", message)
            notification = Gio.Notification.new("Doubletake")
            notification.set_body(message)
            self.send_notification("error", notification)

        def item(self, menu, label, callback=None):
            item = Gtk.MenuItem.new_with_label(label)
            if callback is None:
                item.set_sensitive(False)
            else:
                def activate(widget):
                    widget.set_sensitive(False)
                    callback()

                item.connect("activate", activate)
            menu.append(item)
            return item

        def render(self, error=""):
            rows = receivers(self.status, self.devices)
            view = (rows, summary(self.status), error)
            if view == self.last_view:
                return
            self.last_view = view
            menu = Gtk.Menu()
            self.item(menu, summary(self.status))
            if error:
                self.item(menu, error[:160])
            menu.append(Gtk.SeparatorMenuItem())
            if not rows:
                self.item(menu, "Searching for AirPlay receivers…" if not error else "No receivers available")
            for row in rows:
                ip, name, state = row["ip"], row["name"], row["state"]
                label = f"{name} ({ip})"
                if state == "idle":
                    self.item(menu, label, lambda ip=ip, port=row["port"]: self.action("connect", target=ip, port=port))
                    continue
                submenu = Gtk.Menu()
                state_label = {"streaming": "Mirroring", "pin_required": "Pairing required"}.get(state, "Connecting…")
                receiver = Gtk.MenuItem.new_with_label(f"{label} — {state_label}")
                receiver.set_submenu(submenu)
                menu.append(receiver)
                if state == "pin_required":
                    self.item(submenu, "Enter pairing credential…", lambda row=row: self.prompt(row))
                if state == "streaming" and row.get("has_audio"):
                    muted = row.get("audio_muted", False)
                    self.item(submenu, "Unmute" if muted else "Mute", lambda ip=ip, muted=muted: self.action("unmute" if muted else "mute", target=ip))
                self.item(submenu, "Stop" if state == "streaming" else "Cancel", lambda ip=ip: self.action("disconnect", target=ip))
            menu.append(Gtk.SeparatorMenuItem())
            self.item(menu, "Refresh receivers", self.refresh)
            if any(row["state"] != "idle" for row in rows):
                self.item(menu, "Stop all mirroring", lambda: self.action("disconnect"))
            self.item(menu, "Stop mirroring and quit", self.quit_tray)
            menu.show_all()
            self.indicator.set_menu(menu)
            active = any(row["state"] == "streaming" for row in rows)
            icon = "network-transmit-receive-symbolic" if active else "video-display-symbolic"
            self.indicator.set_icon_full(icon, summary(self.status))

        def refresh(self):
            self.last_view = None
            self.action_error = ""
            self.poll()

        def update_dialogs(self, rows):
            waiting = {row["ip"]: row for row in rows if row["state"] == "pin_required"}
            for ip in list(self.dialogs):
                if ip not in waiting:
                    self.dialogs.pop(ip).destroy()
            self.submitting.intersection_update(waiting)
            for ip, row in waiting.items():
                if ip not in self.dialogs and ip not in self.submitting:
                    self.prompt(row)

        def prompt(self, row):
            ip = row["ip"]
            if ip in self.dialogs:
                self.dialogs[ip].present()
                return
            password = row.get("credential_kind") == "password"
            dialog = Gtk.Dialog(title=f"Pair with {row['name']}")
            dialog.add_buttons("Cancel", Gtk.ResponseType.CANCEL, "Connect", Gtk.ResponseType.OK)
            dialog.set_default_response(Gtk.ResponseType.OK)
            content = dialog.get_content_area()
            content.set_border_width(18)
            content.set_spacing(12)
            text = "Enter the configured AirPlay password:" if password else "Enter the AirPlay code shown on the receiver:"
            content.add(Gtk.Label(label=text))
            entry = Gtk.Entry()
            entry.set_visibility(not password)
            entry.set_activates_default(True)
            content.add(entry)

            def respond(widget, response):
                credential = entry.get_text()
                if response == Gtk.ResponseType.OK and not credential:
                    return
                self.dialogs.pop(ip, None)
                self.submitting.add(ip)
                widget.destroy()
                if response == Gtk.ResponseType.OK:
                    self.action("connect", target=ip, pin=credential)
                else:
                    self.action("disconnect", target=ip)

            dialog.connect("response", respond)
            self.dialogs[ip] = dialog
            dialog.show_all()
            dialog.present()

        def quit_tray(self):
            if self.closing:
                return GLib.SOURCE_REMOVE
            self.closing = True
            if self.timer:
                GLib.source_remove(self.timer)
            self.submit(lambda: self.client.request("disconnect"), self.quit_done)
            return GLib.SOURCE_REMOVE

        def quit_done(self, response, error):
            if error:
                logging.error("Could not stop mirroring: %s", error)
            self.quit()

        def do_shutdown(self):
            self.closing = True
            for dialog in self.dialogs.values():
                dialog.destroy()
            self.executor.shutdown(wait=False, cancel_futures=True)
            Gtk.Application.do_shutdown(self)

    return Tray()


def main():
    logging.basicConfig(level=logging.INFO)
    return create_application().run(sys.argv)


if __name__ == "__main__":
    raise SystemExit(main())
