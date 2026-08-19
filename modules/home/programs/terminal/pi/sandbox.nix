# Pi Bubblewrap Sandbox - Wraps `pi` in a user-namespace sandbox so a rogue
# tool call can only touch the cwd and pi's own state. $HOME is replaced by a
# tmpfs, so anything not bound below (SSH keys, browser profiles, other repos)
# is simply absent rather than merely unwritable.
{ lib
, pkgs
, piPackage
, roBinds
, rwBinds
, shareNet
, bindSshAgent
}:
let
  # Bind Loop - Emitted only for non-empty lists, since `for x in ; do` is a
  # bash syntax error.
  bindLoop = flag: paths:
    lib.optionalString (paths != [ ]) ''
      for path in ${lib.concatMapStringsSep " " (p: ''"${p}"'') paths}; do add_bind ${flag} "$path"; done
    '';

  sandboxed = pkgs.writeShellApplication {
    name = "pi";
    runtimeInputs = [ pkgs.bubblewrap ];
    text = ''
      # Nested Invocation Guard - Subagents re-exec `pi`, and bwrap cannot nest
      # inside its own user namespace.
      if [ "''${PI_SANDBOX:-0}" = "1" ]; then
        exec ${piPackage}/bin/pi "$@"
      fi

      runtime_dir="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

      args=(
        --ro-bind /nix/store /nix/store
        --ro-bind /etc /etc
        --proc /proc
        --dev /dev
        --tmpfs /run
        --ro-bind /run/current-system/sw /run/current-system/sw
        --tmpfs /tmp
        --tmpfs "$HOME"
        --tmpfs "$runtime_dir"
        --bind "$HOME/.pi" "$HOME/.pi"
      )

      add_bind() {
        if [ -e "$2" ]; then
          args+=("$1" "$2" "$2")
        fi
      }

      ${bindLoop "--ro-bind" roBinds}
      ${bindLoop "--bind" rwBinds}

      ${lib.optionalString bindSshAgent ''
        if [ -n "''${SSH_AUTH_SOCK:-}" ]; then
          args+=(--ro-bind "$SSH_AUTH_SOCK" "$SSH_AUTH_SOCK")
        fi
      ''}
      ${lib.optionalString (!bindSshAgent) ''args+=(--unsetenv SSH_AUTH_SOCK)''}

      # Working Directory Last - Later binds win, so this re-exposes the cwd
      # read-write even when it sits under a read-only bind such as /etc.
      args+=(--bind "$PWD" "$PWD" --chdir "$PWD")

      exec bwrap \
        "''${args[@]}" \
        --unshare-all ${lib.optionalString shareNet "--share-net"} \
        --die-with-parent \
        --setenv PI_SANDBOX 1 \
        ${piPackage}/bin/pi "$@"
    '';
  };

  dangerous = pkgs.runCommand "pi-dangerous" { } ''
    mkdir -p $out/bin
    ln -s ${piPackage}/bin/pi $out/bin/pi-dangerous
  '';
in
{ inherit sandboxed dangerous; }
