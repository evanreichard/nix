# Description

This repository contains the configuration for multiple machines, as well as my home / IDE config (home-manager).

## Home Manager

Utilizing [Home Manager](https://nix-community.github.io/home-manager/)

## NixOS

### Copy Config

```bash
scp -r * root@10.10.10.10:/etc/nixos
```

### Partition Drives

```bash
# Validate Disk
ls -l /dev/disk/by-id

# Partition Disk
# WARNING: This will destroy all data on the disk(s)
sudo nix \
    --experimental-features "nix-command flakes" \
    run github:nix-community/disko -- \
    --mode disko \
    --flake /etc/nixos#lin-va-rke1
```

### Install NixOS

```bash
# Install
sudo nixos-install --flake /etc/nixos#lin-va-rke1

# Reboot
sudo reboot
```

### Copy Config Back to Host

```bash
scp -r * nixos@10.0.20.201:/etc/nixos
```

### Rebuild NixOS

```bash
sudo nixos-rebuild switch
```

# Install Kubernetes (RKE2)

```
# Deploy First Node
sudo nixos-install --flake /etc/nixos#lin-va-rke1

# Reboot & Get Token
cat /var/lib/rancher/rke2/server/node-token

# Deploy Following Nodes
echo "<TOKEN>" > ./_scratch/rke2-token
sudo nixos-install --flake /etc/nixos#lin-va-rke2
```

### Notes

### Kasten Port Forward

```bash
kubectl port-forward -n kasten svc/gateway 8000:80
```
