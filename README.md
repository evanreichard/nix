# Description

This repository contains the configuration for multiple machines, as well as my home / IDE config (home-manager).

### NixOS

```bash
sudo nixos-rebuild switch --flake .#lin-va-mbp-personal
```

### NixOS Generators

```bash
nix build .#vmwareConfigurations.rke2-node
```

### Home Manager

```bash
home-manager switch --flake .#evanreichard@MBP-Personal
```

### NixOS Hosts

#### Copy Config

```bash
rsync -av --exclude='.git' . root@HOST:/etc/nixos
```

#### Partition Drives

```bash
# Validate Disk
ls -l /dev/disk/by-id

# Partition Disk
# WARNING: This will destroy all data on the disk(s)
sudo nix \
    --experimental-features "nix-command flakes" \
    run github:nix-community/disko -- \
    --mode disko \
    --flake /etc/nixos#HOST_CONFIG
```

#### Install NixOS

```bash
# Install
sudo nixos-install --flake /etc/nixos#HOST_CONFIG

# Reboot
sudo reboot
```

#### Copy Config Back to Host

```bash
rsync -av --exclude='.git' . root@HOST:/etc/nixos
```

#### Rebuild NixOS

```bash
sudo nixos-rebuild switch
```
