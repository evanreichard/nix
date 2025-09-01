# Description

This repository contains the configuration for multiple machines, as well as my home / IDE config (home-manager).

### NixOS

```bash
sudo nixos-rebuild switch --flake .#lin-va-mbp-personal
```

### NixOS Generators

```bash
nix build .#qcowConfigurations.lin-va-rke2
```

### Home Manager

```bash
home-manager switch --flake .#evanreichard@mac-va-mbp-personal
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

# Nix Home Manager Configuration - macOS

## Upgrade

```bash
# Update System Channels
sudo nix-channel --add https://nixos.org/channels/nixpkgs-25.05-darwin nixpkgs
sudo nix-channel --update

# Update Home Manager
nix-channel --add https://github.com/nix-community/home-manager/archive/release-25.05.tar.gz home-manager
nix-channel --update

# Link Repo
ln -s /Users/evanreichard/Development/git/personal/nix/home-manager ~/.config/home-manager

# Build Home Manager
home-manager switch
```

## Clean Garbage

NOTE: This will remove previous generations

```bash
sudo nix-collect-garbage --delete-old
nix-collect-garbage --delete-old
```

## OS Update

`/etc/bashrc` may get overridden. To properly load Nix, prepend the following:

```bash
# Nix
if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
  . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
fi
# End Nix
```

# Nix Darwin

```bash
# Install Nix Without Determinate
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install

# Switch Nix Darwin
sudo nix run nix-darwin#darwin-rebuild -- switch --flake .#mac-va-mbp-personal
sudo darwin-rebuild switch --flake .#mac-va-mbp-personal
```
