# Storage Box backups

Encrypted Restic backups over SFTP, using native NixOS services and systemd timers.
Each named job gets a repository at `nixos/<hostname>/<job>` on the Storage Box.

```nix
reichard.services.backup = {
  enable = true;
  jobs.documents = {
    paths = [ "/srv/documents" ];
    schedule = "*-*-* 03:15:00";
  };
};
```

The destination lives encrypted in `secrets/common/backups.yaml`; credentials live
in `secrets/systems/<hostname>.yaml`. See [setup and recovery](docs.md) for SOPS
setup and Headscale activation steps.

Defaults retain 7 daily, 4 weekly, and 12 monthly snapshots. Timers catch up after
downtime and add up to 15 minutes of jitter. Each run checks repository integrity
and reads a random 5% of stored data. Advanced options use
`services.restic.backups.<job>` directly.
