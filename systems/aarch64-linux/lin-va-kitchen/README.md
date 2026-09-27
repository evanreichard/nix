# Kitchen Pi SD image

Build with `nix build .#nixosConfigurations.lin-va-kitchen.config.system.build.sdImage` on a host with an AArch64 builder. This combines the Nixpkgs AArch64 SD-image module with the `nixos-hardware` Pi 4 profile. The image contains a FAT firmware partition and ext4 root; Disko is not used.

Check the destination with `lsblk` before flashing. This **erases the whole device**:

```bash
zstd -dc result/sd-image/*.img.zst | sudo dd of=/dev/mmcblk0 bs=4M conv=fsync status=progress
```

Ethernet remains managed by NetworkManager with DHCP. `wlan0` is managed by wpa_supplicant using `wifi_ssid` and `wifi_psk` from `secrets/systems/lin-va-kitchen.yaml`. A fresh image does not contain the SOPS private key matching that file's Pi recipient; restore it before relying on Wi-Fi, or use Ethernet for initial access.

The Pi's SSH key is authorized only on `lin-va-nix-builder`, not in the shared OpenSSH key list. Deploy the builder's configuration before expecting the Pi to use it as a builder or substituter. This limits which hosts accept the key, but the existing builder account still provides a shell and trusted Nix access.
