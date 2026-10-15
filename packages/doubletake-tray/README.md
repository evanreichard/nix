# Doubletake Tray

A native GTK/StatusNotifier tray for Doubletake: discover AirPlay receivers, pair, mirror your screen, and mute or stop each receiver. Doubletake handles capture and streaming; the tray communicates over its local Unix socket.

Enable it in Home Manager:

```nix
reichard.programs.graphical.doubletake = {
  enable = true;
  tray = true;
};
```

The tray starts with the graphical session. Launch **AirPlay Mirroring** from the app menu to reopen it after quitting. Pairing and screen-capture prompts appear when connecting.

Logs:

```sh
journalctl --user -u doubletake -u doubletake-tray -f
```

Doubletake has no underscan control, so the tray does not expose one.
