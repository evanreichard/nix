# Backup setup and recovery

## Shared destination

`secrets/common/backups.yaml` stores the destination as encrypted `storagebox.host`,
`storagebox.user`, and `storagebox.host_key` values. Its SOPS recipients should include
only the admin key and backup hosts. Add new backup hosts to its creation rule and
run `sops updatekeys secrets/common/backups.yaml` before deploying them.

SOPS renders root-only SSH configuration, known-hosts, and repository files at
activation. Plaintext destination details stay out of Git and the Nix store.

## Credentials

Create `secrets/systems/<hostname>.yaml` with SOPS. Its creation rule must include
your admin recipient and the host's SSH-derived age recipient. Each job needs:

```yaml
backups:
  documents:
    password: <unique Restic encryption password>
    ssh_key: |
      -----BEGIN OPENSSH PRIVATE KEY-----
      ...
      -----END OPENSSH PRIVATE KEY-----
```

Authorize the corresponding SSH public key on the Storage Box. Use a unique
password for each new repository; existing repositories require their original
password. Keep an independent recovery copy of the password. Separate repositories
isolate retention, not Storage Box access permissions.

The module decrypts these values as root-only files using the host SSH key, without
enabling unrelated SOPS-backed services. The SFTP server host key is pinned.

## Jobs

Schedules are systemd calendar expressions interpreted in the host time zone.
Native `services.restic.backups.<job>` settings control exclusions, retention, and
consistency hooks. Live databases require staging or an application-aware snapshot;
simply copying their directory while running is unsafe.

## Headscale activation

`lin-o1-headscale` has backups enabled and credentials in
`secrets/systems/lin-o1-headscale.yaml`. Its shared destination is encrypted in
`secrets/common/backups.yaml`. The host's recipient is in both `.sops.yaml` rules;
the SSH key is reused from the Kubernetes backup.

After rebuilding the host, run `sudo systemctl start restic-backups-headscale`
and inspect `journalctl -u restic-backups-headscale` and `systemctl list-timers`.

The preparation hook briefly stops Headscale to copy `/var/lib/headscale` into a
private local staging directory, then restarts it before initializing/uploading to
the repository. Cleanup also attempts a restart if preparation fails or is killed.
Only the staged directory is uploaded. A host crash still requires normal boot
recovery; no shell trap can guarantee recovery from a crash.

## Restore checks

On a configured host, the native wrapper supplies repository and credential paths:

```sh
sudo restic-headscale snapshots
sudo restic-headscale check --read-data
sudo restic-headscale restore latest --target /var/tmp/headscale-restore
```

A Headscale snapshot restores under
`/var/tmp/headscale-restore/var/lib/headscale-backup/snapshot/`. Inspect its database
and keys. For a real recovery, stop Headscale and restore that directory's contents
to `/var/lib/headscale`, preserving ownership and permissions, before starting it.
Keep the Nix configuration/ACL in Git. Periodically test a restore on an isolated
host; repository checks alone cannot validate application recovery.
