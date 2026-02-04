# Description

This repository contains the configuration for multiple machines, as well as my home / IDE config (home-manager).

```bash
# Install NixOS
./bootstrap.sh install --name lin-va-nix-builder

# Remote Image Build (NixOS Builder)
./bootstrap.sh image --name lin-va-rke2 --remote

# Home Manager Install
home-manager switch --flake .#evanreichard@mac-va-mbp-personal

# Update Flake
nix flake update
```

## Manual

```bash
# Install NixOS
sudo nixos-rebuild switch --flake .#lin-va-mbp-personal

# Install NixOS (Remote)
nix run github:nix-community/nixos-anywhere -- --flake .#lin-cloud-kube1 --target-host \<USER\>@\<IP\>

# Build Image
nix build .#vmwareConfigurations.lin-va-rke2
```

## Nix Darwin

```bash
# Install Nix Without Determinate
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install

# Switch Nix Darwin
sudo nix run nix-darwin#darwin-rebuild -- switch --flake .#mac-va-mbp-personal
sudo darwin-rebuild switch --flake .#mac-va-mbp-personal
```

## Clean Garbage

NOTE: This will remove previous generations

```bash
sudo nix-collect-garbage --delete-old
nix-collect-garbage --delete-old
```

## Home Manager

```bash
# Update System Channels
sudo nix-channel --add https://nixos.org/channels/nixpkgs-25.11-darwin nixpkgs
sudo nix-channel --update

# Update Home Manager
nix-channel --add https://github.com/nix-community/home-manager/archive/release-25.11.tar.gz home-manager
nix-channel --update

# Link Repo
ln -s /Users/evanreichard/Development/git/personal/nix/home-manager ~/.config/home-manager

# Build Home Manager
home-manager switch
```

### OS Update

`/etc/bashrc` may get overridden. To properly load Nix, prepend the following:

```bash
# Nix
if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
  . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
fi
# End Nix
```

#### SOPS

1. Convert your SSH key to an age key
2. Get age public key
3. Update `.sops.yaml` with rules
4. Edit file

```bash
# Convert SSH to Age
mkdir -p ~/.config/sops/age
ssh-to-age -private-key -i $HOME/.ssh/id_ed25519 -o ~/.config/sops/age/keys.txt

# Get Public Key
age-keygen -y ~/.config/sops/age/keys.txt
ssh-to-age -private-key -i ~/.ssh/id_ed25519 | age-keygen -y
SOPS_AGE_KEY_FILE=<ADMIN_KEY> sops -d --extract '["lin-va-desktop"]["host"]' ./secrets/keys.yaml | ssh-to-age -private-key | age-keygen -y

# Edit File
# NOTE: You can specify key with - `SOPS_AGE_KEY_FILE=~/.config/sops/age/other.txt`
sops secrets/lin-va-thinkpad/evanreichard/default.yaml
```
