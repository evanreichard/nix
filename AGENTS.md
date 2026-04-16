# NixOS Configuration — Agent Guide

This is a multi-host NixOS/nix-darwin configuration managed with [Snowfall Lib](https://github.com/snowfallorg/lib). It declaratively configures NixOS (Linux), nix-darwin (macOS), and Home Manager across many machines from a single flake.

## Snowfall Lib Conventions

Snowfall Lib auto-discovers everything by directory convention — there is no manual wiring. The namespace is `reichard`, so all custom options live under `reichard.*` (e.g. `reichard.services.tailscale`, `reichard.programs.terminal.nvim`). Modules use `lib.reichard.enabled` / `lib.reichard.disabled` helpers from `lib/module/default.nix`.

**Important:** Files must be tracked by git (`git add`) for the flake to see them.

## Layout

### `flake.nix`

Entrypoint. Defines inputs (nixpkgs, home-manager, sops-nix, disko, apple-silicon, snowfall-lib, etc.) and calls `snowfall-lib.mkFlake`. All system and home modules are auto-discovered from the directory structure below.

### `systems/`

System-level NixOS and nix-darwin configurations, organized by architecture:

- `systems/aarch64-linux/` — ARM Linux hosts (e.g. Asahi MacBook, Oracle Cloud nodes, headscale)
- `systems/x86_64-linux/` — x86 Linux hosts (desktop, thinkpad, utility servers, Kubernetes nodes)
- `systems/aarch64-darwin/` — macOS hosts (work and personal MacBooks)
- `systems/aarch64-raw-efi/` — Raw EFI image builds (terminal image via nixos-generators)
- `systems/x86_64-vmware/` — VMware images (RKE2 node)

Each host is a directory with a `default.nix` that composes modules via the `reichard.*` option namespace (e.g. `reichard.services.tailscale = enabled;`). Some hosts include `hardware-configuration.nix` or firmware directories.

### `homes/`

Home Manager configurations, organized by `<arch>/<user>@<host>/default.nix`. Each home config enables per-host programs and services (e.g. Neovim, Firefox, Hyprland, git, tmux) via the `reichard.*` namespace, same as system modules.

### `modules/`

Reusable NixOS, Home Manager, and Darwin modules. This is where most of the configuration logic lives.

- **`modules/nixos/`** — NixOS system modules:
  - `common/` — Packages applied to all NixOS systems
  - `home/` — Home Manager integration (useGlobalPkgs, useUserPackages)
  - `nix/` — Nix daemon settings, registries, binary caches, distributed builds
  - `user/` — User account creation
  - `security/sops/` — sops-nix secret decryption (age-based)
  - `system/` — Boot, networking, NetworkManager, disko disk partitioning
  - `services/` — Headscale, Tailscale, llama-swap (LLM model server), OpenSSH, RKE2, printing, Avahi, cloud-init, Sunshine, etc.
  - `hardware/` — OpenGL, Asahi (Apple Silicon), battery/UPower
  - `programs/graphical/wms/hyprland/` — System-level Hyprland WM setup
  - `display-managers/sddm/` — SDDM display manager
  - `virtualisation/` — Podman, libvirtd

- **`modules/home/`** — Home Manager modules:
  - `common/` — Packages applied to all home configs (sqlite, jq, ripgrep, ncdu, jnv)
  - `user/` — Home Manager user identity
  - `security/sops/` — Per-user secret decryption
  - `services/` — Fusuma (touchpad gestures), swww (wallpaper), SSH agent, poweralertd
  - `programs/terminal/` — CLI tools: bash, tmux, btop, git, k9s, zk, aws, Neovim, opencode, claude-code, pi
  - `programs/graphical/` — GUI apps: Firefox (with extensions overlay), Ghostty, Hyprland (home-level), Remmina, GIMP, Wireshark, Ghidra, Strawberry

- **`modules/darwin/`** — nix-darwin modules: user, OpenSSH, sops

### `modules/home/programs/terminal/nvim/` — Neovim Configuration

This is the full Neovim setup, frequently modified. The `default.nix` declares:
- All plugins (via nixpkgs vimPlugins + custom `buildVimPlugin` for codecompanion.nvim, none-ls-extras, llama.vim)
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
- `diagnostics-config.lua`, `ts-config.lua`, `lualine-config.lua`, `noice-config.lua`, `git-config.lua`, `which-key-config.lua`, etc.

When editing the Neovim config, note that **plugin declarations** happen in `default.nix` (Nix), while **plugin configuration** happens in the Lua files under `config/lua/`. LSP binary paths are bridged via the auto-generated `nix-vars.lua`.

### `packages/`

Custom package derivations, auto-discovered by Snowfall Lib and available as `pkgs.reichard.<name>`:

- `codexis/` — Go: code indexer using tree-sitter (built from gitea via `fetchgit`)
- `llama-cpp/` — LLaMA C++ inference engine
- `llama-swap/` — Go: LLM model swap proxy (with UI sub-derivation)
- `opencode/` — Go: terminal coding tool
- `pi-coding-agent/` — Node.js: coding agent CLI
- `qwen-code/` — Qwen code assistant
- `stable-diffusion-cpp/` — Stable Diffusion C++ inference

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

## Common Tasks

- **Adding a new system:** Create `systems/<arch>/<hostname>/default.nix` and optionally `homes/<arch>/<user>@<hostname>/default.nix`. Compose existing modules via `reichard.*` options.
- **Adding a new module:** Create `modules/{nixos,home,darwin}/<category>/<name>/default.nix` with an `enable` option under the `reichard` namespace. It will be auto-discovered.
- **Adding a new package:** Create `packages/<name>/default.nix`. Run `git add` so the flake sees it. Reference it in modules as `pkgs.reichard.<name>`.
- **Editing Neovim plugins:** Modify `modules/home/programs/terminal/nvim/default.nix` (plugin list, extraPackages, nix-vars).
- **Editing Neovim config (Lua):** Modify files under `modules/home/programs/terminal/nvim/config/lua/`.
- **Managing secrets:** Edit `.sops.yaml` for key groups, use `sops` CLI to encrypt/decrypt files in `secrets/`.
- **Building/testing:** `nix build .#packages.<arch>.<name>` for packages, `nix build .#nixosConfigurations.<host>.config.system.build.toplevel` for full system builds.
- **Bumping a package version / refreshing hashes:** Use the `update-package-hashes` skill at `.pi/skills/update-package-hashes/`.
