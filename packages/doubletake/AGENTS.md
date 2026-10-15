# Doubletake Packaging

GStreamer's default output is `bin`; its core plugins (`queue`, `fdsink`, `identity`) are in `gstreamer.out`. An explicit `GST_PLUGIN_SYSTEM_PATH_1_0` must include that output as well as the separate plugin packages. Interactive sessions can mask omissions through inherited plugin paths; keep the runtime pipeline check isolated from those paths and `NIX_PROFILES`.
