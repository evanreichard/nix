# Coding Agent Bubblewrap Sandbox - Wraps an agent CLI in a user-namespace sandbox so a rogue
# tool call can only touch the cwd and the agent's own state. $HOME is replaced by a tmpfs, so
# anything not bound below (SSH keys, browser profiles, other repos) is simply absent rather
# than merely unwritable.
#
# `name` drives the binary name, the `$HOME/.<name>` state bind, and the `<NAME>_SANDBOX` guard,
# so every agent that keeps its state in a single dotdir shares this wrapper unchanged.
{ lib
, pkgs
, name
, package
, roBinds
, rwBinds
, shareNet
, bindSshAgent
}:
let
  guardVar = "${lib.toUpper name}_SANDBOX";
  binary = "${package}/bin/${name}";

  # Bind Loop - Emitted only for non-empty lists, since `for x in ; do` is a
  # bash syntax error.
  bindLoop = flag: paths:
    lib.optionalString (paths != [ ]) ''
      for path in ${lib.concatMapStringsSep " " (p: ''"${p}"'') paths}; do add_bind ${flag} "$path"; done
    '';

  sandboxed = pkgs.writeShellApplication {
    inherit name;
    runtimeInputs = [ pkgs.bubblewrap ];
    text = ''
      # Nested Invocation Guard - Subagents re-exec `${name}`, and bwrap cannot
      # nest inside its own user namespace.
      if [ "''${${guardVar}:-0}" = "1" ]; then
        exec ${binary} "$@"
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
        --bind "$HOME/.${name}" "$HOME/.${name}"
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
        --setenv ${guardVar} 1 \
        ${binary} "$@"
    '';
  };

  dangerous = pkgs.runCommand "${name}-dangerous" { } ''
    mkdir -p $out/bin
    ln -s ${binary} $out/bin/${name}-dangerous
  '';
in
{ inherit sandboxed dangerous; }
