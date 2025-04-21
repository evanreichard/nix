#!/bin/sh

export NIX_CONFIG="experimental-features = nix-command flakes"

function cmd_image() {
    local usage="Usage: $0 image --name <image-name> [--remote]"
    local name=""
    local remote=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --name)
                name="$2"
                shift 2
                ;;
            --remote)
                remote=true
                shift
                ;;
            *)
                echo "$usage"
                exit 1
                ;;
        esac
    done

    if [ -z "$name" ]; then
        echo "$usage"
        exit 1
    fi

    # Validate Config Exists
    if ! nix eval --json --impure \
        ".#qcowConfigurations" \
        --apply "s: builtins.hasAttr \"$name\" s" 2>/dev/null | grep -q "true"; then
        echo "Error: NixOS Generator Config '$name' not found"
        exit 1
    fi

    build_args=(".#qcowConfigurations.$name")
    if [ "$remote" = true ]; then
        build_args+=("-j0")
    fi

    if ! nix build "${build_args[@]}"; then
        echo "Error: Image build failed"
        exit 1
    fi

    echo "Successfully built image: $name"
}

function cmd_install() {
    local usage="Usage: $0 install --name <system-name>"
    local name=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --name)
                name="$2"
                shift 2
                ;;
            *)
                echo "$usage"
                exit 1
                ;;
        esac
    done

    if [ -z "$name" ]; then
        echo "$usage"
        exit 1
    fi

    # Validate Config Exists
    if ! nix eval --json --impure \
        ".#nixosConfigurations" \
        --apply "s: builtins.hasAttr \"$name\" s" 2>/dev/null | grep -q "true"; then
        echo "Error: NixOS configuration '$name' not found"
        exit 1
    fi

    # Validate mainDiskID Exists
    if ! disk_id=$(nix eval --raw --impure \
	".#nixosConfigurations.$name.config.disko.devices.disk.main.device" 2>/dev/null); then
        echo "Error: mainDiskID not defined for configuration '$name'"
        exit 1
    fi

    # Validate Disk Exists
    if [ ! -e "$disk_id" ]; then
        echo "Error: Disk $disk_id not found on system"
        exit 1
    fi

    # Prompt Format
    read -p "This will format disk $disk_id. Continue? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Operation Cancelled"
        exit 1
    fi
    echo "Formatting disk: $disk_id"

    # Format Disk
    if ! sudo nix \
        --experimental-features "nix-command flakes" \
        run github:nix-community/disko -- \
        --mode disko \
        --flake "/etc/nixos#$name"; then
        echo "Error: Disk formatting failed"
        exit 1
    fi

    # Install NixOS
    echo "Installing $name to disk: $disk_id"
    if ! sudo nixos-install --flake "/etc/nixos#$name"; then
        echo "Error: NixOS installation failed"
        exit 1
    fi
    echo "Successfully installed $name to disk: $disk_id"

    # Prompt Reboot
    read -p "Reboot? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Operation Complete - Not Rebooting"
        exit 0
    fi

    # Reboot
    echo "Operation Complete - Rebooting"
    sudo reboot
}

case "$1" in
    image)
        shift
        cmd_image "$@"
        ;;
    install)
        shift
        cmd_install "$@"
        ;;
    *)
        echo "Usage: $0 {image|install} --name <name>"
        exit 1
        ;;
esac
