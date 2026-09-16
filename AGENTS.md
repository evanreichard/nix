# NixOS Configuration — Agent Guide

This is a multi-host NixOS/nix-darwin configuration managed with [Snowfall Lib](https://github.com/snowfallorg/lib). It declaratively configures NixOS (Linux), nix-darwin (macOS), and Home Manager across many machines from a single flake.

**Writing AGENTS.md files:** record only what an agent cannot read off the code — measured
constants, upstream constraints, and decisions whose rationale is invisible in the diff.
Nix modules are self-describing, so narrating structure or restating flags is cost without
value. Prefer replacing a stale note over appending a newer one; a session log is not a guide.

## Snowfall Lib Conventions

Snowfall Lib auto-discovers everything by directory convention — there is no manual wiring. The namespace is `reichard`, so all custom options live under `reichard.*` (e.g. `reichard.services.tailscale`, `reichard.programs.terminal.nvim`). Modules use `lib.reichard.enabled` / `lib.reichard.disabled` helpers from `lib/module/default.nix`.

**Important:** Files must be tracked by git (`git add`) for the flake to see them.

Home modules receive Snowfall's `lib` (nixpkgs lib + `lib.reichard`), not Home Manager's extended lib: `lib.hm.*` and `config.lib.hm` are both absent. Use plain `lib`/`builtins` in place of helpers like `lib.hm.strings.isPathLike` or `lib.hm.assertions.assertPlatform`.

## Layout

### `flake.nix`

Entrypoint. Inputs: `nixpkgs` (nixos-26.05), `nixpkgs-unstable`, `home-manager`, `disko`, `determinate`, `darwin`, `sops-nix`, `apple-silicon`, `nixos-generators`, `firefox-addons`, `snowfall-lib`. Calls `snowfall-lib.mkFlake`; all system and home modules are auto-discovered from the directory structure below. `channels-config` sets `allowUnfree` and permits `intel-ocl-5.0-63503`.

### `systems/`

System-level NixOS and nix-darwin configurations, organized by architecture:

- `systems/aarch64-linux/` — ARM Linux hosts (Asahi MacBook, Oracle Cloud nodes, headscale)
- `systems/x86_64-linux/` — x86 Linux hosts (desktop, personal laptop, office, terminal, nix builder, utility servers, Kubernetes nodes)
- `systems/aarch64-darwin/` — macOS hosts (work and personal MacBooks)
- `systems/aarch64-raw-efi/` — Raw EFI image builds (terminal image via nixos-generators)
- `systems/x86_64-vmware/` — VMware image (RKE2 node)

Each host is a directory with a `default.nix` that composes modules via the `reichard.*` option namespace (e.g. `reichard.services.tailscale = enabled;`). Some hosts include `hardware-configuration.nix` or firmware directories.

### `homes/`

Home Manager configurations, organized by `<arch>/<user>@<host>/default.nix`. Most hosts have no home config, so this tree is smaller than `systems/`. Each home config enables per-host programs and services (e.g. Neovim, Firefox, Hyprland, git, tmux) via the `reichard.*` namespace, same as system modules.

### `modules/`

Reusable NixOS, Home Manager, and Darwin modules. This is where most of the configuration logic lives.

- **`modules/nixos/`** — NixOS system modules:
  - `common/` — Packages applied to all NixOS systems
  - `home/` — Home Manager integration (useGlobalPkgs, useUserPackages)
  - `nix/` — Nix daemon settings, registries, binary caches, distributed builds
  - `user/` — User account creation
  - `security/sops/` — sops-nix secret decryption (age-based)
  - `system/` — `boot/`, `networking/` (incl. `networkmanager/`), `disk/` (disko partitioning)
  - `services/` — Headscale, Tailscale, llama-swap (LLM inference front end), OpenSSH, RKE2, printing, OctoPrint, mosh, RTL-TCP, ydotool, Open-iSCSI, Avahi, cloud-init, Sunshine
  - `hardware/` — OpenGL, Asahi (Apple Silicon), battery/UPower
  - `programs/graphical/wms/hyprland/` — System-level Hyprland WM setup
  - `display-managers/sddm/` — SDDM display manager
  - `virtualisation/` — Podman, libvirtd

- **`modules/home/`** — Home Manager modules:
  - `common/` — Packages applied to all home configs (sqlite-interactive, jq, ripgrep, ncdu, jnv, unzip, mosh, codexis)
  - `user/` — Home Manager user identity
  - `security/sops/` — Per-user secret decryption; `security/pass-keyring/` — GPG/pass-backed keyring for CLI credential storage on hosts without a working D-Bus SecretService
  - `services/` — awww (wallpaper; succeeded swww), open-proxy, sketchybar, nunc (the latter two macOS-only), fusuma (touchpad gestures), SSH agent, poweralertd
  - `programs/terminal/` — CLI tools: bash, tmux, btop, git, k9s, zk, aws, direnv, Neovim, scripts; coding agents: opencode, claude-code, pi, omp, conduit, glimpse
  - `programs/graphical/` — GUI apps: kitty, Ghostty, Firefox (with extensions overlay), Hyprland (home-level), omniwm (macOS), Remmina, GIMP, Wireshark, Ghidra, Strawberry

- **`modules/darwin/`** — nix-darwin modules: user, openssh, sops

### `modules/nixos/services/llama-swap/` — Model Catalogue

Owns every deployed inference model: `models/*.nix` definitions (llama.cpp presets and vLLM profiles on the syv-ai backend), `lib/backends.nix`, and the service config. Its own `AGENTS.md` is authoritative for model invariants — geometry, VRAM budgets, health-check timeouts, image pins — and is much longer than this file; read it before changing a model. `modules/home/programs/terminal/pi/lib.nix` and `omp/lib.nix` derive the agent model lists from this same catalogue, including `macros.ctx` → `contextWindow`, so those two sides must move together.

### `modules/home/programs/terminal/nvim/` — Neovim Configuration

This is the full Neovim setup, frequently modified. The `default.nix` declares:

- All plugins (via nixpkgs vimPlugins + custom `buildVimPlugin` for codecompanion.nvim, none-ls-extras, llama.vim, each pinned to an explicit rev)
- LSP servers and formatters as `extraPackages`
- A generated `nix-vars.lua` that injects Nix store paths for LSP binaries

The actual Neovim Lua configuration lives in `config/lua/`:

- `init.lua` — Main loader
- `base.lua` — Core Vim settings and keymaps
- `lsp-config.lua` — LSP server setup (uses paths from `nix-vars.lua`)
- `cmp-config.lua` — nvim-cmp completion
- `llm-config.lua` — LLM integration (codecompanion, llama.vim)
- `snacks-config.lua` — Snacks.nvim dashboard/picker
- `dap-config.lua` — Debug Adapter Protocol (Go, etc.)
- `diagnostics-config.lua`, `ts-config.lua`, `lualine-config.lua`, `noice-config.lua`, `git-config.lua`, `which-key-config.lua`, `toggleterm-config.lua`, `octo-config.lua`, etc.

When editing the Neovim config, note that **plugin declarations** happen in `default.nix` (Nix), while **plugin configuration** happens in the Lua files under `config/lua/`. LSP binary paths are bridged via the auto-generated `nix-vars.lua`.

### `modules/home/programs/terminal/{pi,omp}/` and `agent-shared/`

The coding-agent modules. `pi/` and `omp/` each publish their own model catalogue (see the llama-swap section above). `agent-shared/sandbox.nix` is the shared bubblewrap wrapper factory: it takes `name` + `package` and emits a `<name>-sandboxed` binary beside the unwrapped one, replacing `$HOME` with a tmpfs and binding back only the agent's own `~/.<name>` state dir. Adding an agent means adding a `name`/`package` instantiation, not a new sandbox.

### `modules/home/programs/terminal/scripts/`

Script registry pattern: dropping `bin/<name>.sh` plus a `scriptDefs` entry in `default.nix` (with its `runtimeInputs`) exposes `<name>` on PATH behind a per-script `reichard.programs.terminal.scripts.<name>` enable option.

### `packages/`

Custom package derivations, auto-discovered by Snowfall Lib and available as `pkgs.reichard.<name>`. `meta.description` is the authority; this list is a map, not a spec:

- `audio-cpp/` — C++: ggml inference for audio models (TTS, STT, VAD, music)
- `claude-code/` — Anthropic agent CLI; unfree binary repack, per-platform manifest
- `codexis/` — Go: code index database built on tree-sitter (gitea via `fetchgit`)
- `conduit/` — Go: self-hosted tunneling service
- `evga-icx/` — C: iCX3 fan control and thermistor/VRAM sensors for EVGA 30-series cards (x86_64-linux)
- `glimpse/` — Node: browser automation CLI for inspecting web pages
- `ik-llama-cpp/` — ik_llama.cpp fork, CUDA + Vulkan, CUDA arches pinned per GPU
- `llama-cpp/` — LLaMA C++ inference engine
- `llama-swap/` — Go: LLM model swap proxy (UI split into `ui.nix`)
- `nunc/` — Swift: macOS floating clock overlay
- `omp/` — prebuilt binary repack of the oh-my-pi agent CLI
- `omniwm/` — macOS tiling window manager; repackages the signed upstream release
- `open-proxy/` — Go: forwards `open`/`xdg-open` from a VM to its host
- `opencode/` — Bun: terminal coding agent
- `pi-coding-agent/` — Node: pi coding agent CLI
- `pi-isolate/` — network-isolated bash and brokered Nix installs for omp
- `pi-web/` — Node: local web UI for the pi coding agent
- `qwen-code/` — Node: Qwen code assistant
- `slack-cli/` — Python: reads Slack messages from the local Chromium IndexedDB cache (Darwin)
- `stable-diffusion-cpp/` — Stable Diffusion inference in C/C++
- `tuxguitar/` — Java: multitrack guitar tablature editor

Several packages carry their own `AGENTS.md` (e.g. `llama-cpp/`, `pi-coding-agent/`) — check for one before editing.

### `overlays/`

Nixpkgs overlays. Currently just `firefox-addons/` which imports the rycee Firefox addons repository.

### `secrets/`

sops-encrypted secrets (age keys). Managed via `.sops.yaml` which defines per-host and per-user key groups:

- `keys.yaml` — Master key definitions
- `common/evanreichard.yaml` — User-level secrets (shared across personal machines)
- `common/systems.yaml` — System-level secrets (e.g. builder SSH keys)

### `shells/`

Dev shell definitions. `shells/default/` provides the default `nix develop` environment for working on this repo.

### `lib/`

Shared library helpers. `lib/module/default.nix` exports `mkOpt`, `mkBoolOpt`, `enabled`, and `disabled` — used throughout all modules for consistent option declarations.

### `.agents/skills/`

Repo-local skills:

- `update-package-hashes/` — bump a `packages/` derivation to a new version and refresh `src`/`vendorHash`/`npmDepsHash`/`cargoHash` hashes without compiling it.
- `llm-inference-tuning/` — llama.cpp and vLLM tuning for this repo's hosts; holds the GPU layout, model directories, per-backend references, and `scripts/bench.sh`. Prefer it over ad-hoc benchmarking when changing a llama-swap model.

## Common Tasks

- **Provisioning a host:** `./bootstrap.sh install --name <host>` (add `--remote` for image builds); `./bootstrap.sh image --name <host>`. Manual paths are in `README.md`.
- **Adding a new system:** Create `systems/<arch>/<hostname>/default.nix` and optionally `homes/<arch>/<user>@<hostname>/default.nix`. Compose existing modules via `reichard.*` options.
- **Adding a new module:** Create `modules/{nixos,home,darwin}/<category>/<name>/default.nix` with an `enable` option under the `reichard` namespace. It will be auto-discovered.
- **Adding a new package:** Create `packages/<name>/default.nix`. Run `git add` so the flake sees it. Reference it in modules as `pkgs.reichard.<name>`.
- **Adding a deployed model:** Follow `modules/nixos/services/llama-swap/AGENTS.md`; definitions live in its `models/` directory and are consumed by the agent modules too.
- **Editing Neovim plugins:** Modify `modules/home/programs/terminal/nvim/default.nix` (plugin list, extraPackages, nix-vars).
- **Editing Neovim config (Lua):** Modify files under `modules/home/programs/terminal/nvim/config/lua/`.
- **Managing secrets:** Edit `.sops.yaml` for key groups, use `sops` CLI to encrypt/decrypt files in `secrets/`.
- **Building/testing:** `nix build .#packages.<arch>.<name>` for packages, `nix build .#nixosConfigurations.<host>.config.system.build.toplevel` for full system builds.
- **Bumping a package version / refreshing hashes:** Use the `update-package-hashes` skill at `.agents/skills/update-package-hashes/`.
