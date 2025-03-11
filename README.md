# Description

This repository contains the configuration for multiple machines, as well as my home / IDE config (home-manager).

## Home Manager

Utilizing [Home Manager](https://nix-community.github.io/home-manager/). Check out the [README.md](./home-manager/README.md).

## NixOS

### NixOS Generators

```bash
nix build .#packages.x86_64-linux.rke2-image
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
