# Doubletake Tray

Doubletake's Unix-socket protocol is unversioned. When updating `packages/doubletake`, compare its `Request`, `Response`, and `StreamInfo` types plus credential handling with the tray; the tray's automated GUI tests use a fake daemon and cannot catch upstream schema changes.

Validate the packaged GTK entrypoint as well as the tests. A synthetic receiver plus an isolated session bus/Xvfb can exercise the real daemon and tray without connecting to an Apple TV; SIGTERM should stop the mirror and exit cleanly.
