# claude-code

Nix package for [@anthropic-ai/claude-code](https://www.npmjs.com/package/@anthropic-ai/claude-code).

## Updating

1. Fetch the tarball and generate a `package-lock.json`:

```bash
mkdir /tmp/claude-update && cd /tmp/claude-update
npm pack @anthropic-ai/claude-code@<version>
tar -xf anthropic-ai-claude-code-<version>.tgz
cd package
npm install --package-lock-only --ignore-scripts
```

2. Copy the lockfile into the package directory:

```bash
cp package-lock.json /path/to/nixpkgs/pkgs/by-name/cl/claude-code/package-lock.json
```

3. Update the `version` and `hash` fields in `package.nix`. Set `hash` to `lib.fakeHash` temporarily, then build to get the correct hash:

4. Do the same for `npmDepsHash`:
