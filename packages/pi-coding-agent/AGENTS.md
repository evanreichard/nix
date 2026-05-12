# pi-coding-agent Packaging Notes

`pi-coding-agent` is built from the `earendil-works/pi-mono` monorepo with `buildNpmPackage`.

## Lockfile Metadata

Upstream `package-lock.json` may omit `resolved` / `integrity` metadata that npm can recover online, but Nix needs for its offline npm cache. Keep a package-local enriched lockfile at `packages/pi-coding-agent/package-lock.json` and copy it in during `prePatch` before `npmConfigHook` validates/generates `npmDeps`.

After bumping `version` in `default.nix`, regenerate it with:

```bash
node packages/pi-coding-agent/update-lockfile.mjs
# or explicitly:
node packages/pi-coding-agent/update-lockfile.mjs 0.74.0
```

Then refresh `npmDepsHash` from the FOD mismatch:

```bash
nix build .#packages.aarch64-linux.pi-coding-agent.npmDeps --no-link
```

Remember: new files must be `git add`ed before the flake can see them.
