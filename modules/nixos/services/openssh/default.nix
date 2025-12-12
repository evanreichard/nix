{ config
, lib
, namespace
, ...
}:
let
  inherit (lib)
    types
    mkDefault
    mkIf
    ;
  inherit (lib.${namespace}) mkOpt;

  cfg = config.${namespace}.services.openssh;

  globalKeys = [
    # evanreichard@lin-va-mbp-personal
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILJJoyXQOv9cAjGUHrUcvsW7vY9W0PmuPMQSI9AMZvNY"
    # evanreichard@mac-va-mbp-personal
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMWj6rd6uDtHj/gGozgIEgxho/vBKebgN5Kce/N6vQWV"
    # evanreichard@lin-va-thinkpad
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAq5JQr/6WJMIHhR434nK95FrDmf2ApW2Ahd2+cBKwDz"
    # evanreichard@lin-va-terminal
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM5e6Cty+7rX5BjIEHBTU6GnzfOxPJiHpSqin/BnsypO"
    # evanreichard@mobile
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIARTNbl4lgQsp7SJEng7vprL0+ChC9e6iR7o/PiC4Jme"
  ];
in
{
  options.${namespace}.services.openssh = with types; {
    enable = lib.mkEnableOption "OpenSSH support";
    authorizedKeys = mkOpt (listOf str) [ ] "The public keys to apply.";
    extraConfig = mkOpt str "" "Extra configuration to apply.";
  };

  config = mkIf cfg.enable {
    services.openssh = {
      enable = true;

      hostKeys = mkDefault [
        {
          bits = 4096;
          path = "/etc/ssh/ssh_host_ed25519_key";
          type = "ed25519";
        }
      ];

      openFirewall = true;
      ports = [ 22 ];

      settings = {
        AuthenticationMethods = "publickey";
        ChallengeResponseAuthentication = "no";
        PasswordAuthentication = false;
        PermitRootLogin = "prohibit-password";
        PubkeyAuthentication = "yes";
        StreamLocalBindUnlink = "yes";
        UseDns = false;
        UsePAM = true;
        X11Forwarding = false;

        KexAlgorithms = [
          "curve25519-sha256"
          "curve25519-sha256@libssh.org"
          "diffie-hellman-group16-sha512"
          "diffie-hellman-group18-sha512"
          "diffie-hellman-group-exchange-sha256"
          "sntrup761x25519-sha512@openssh.com"
        ];

        Macs = [
          "hmac-sha2-512-etm@openssh.com"
          "hmac-sha2-256-etm@openssh.com"
          "umac-128-etm@openssh.com"
        ];
      };

      startWhenNeeded = true;
    };

    programs.ssh = {
      startAgent = lib.mkDefault true;
      inherit (cfg) extraConfig;
    };

    reichard = {
      user.extraOptions.openssh.authorizedKeys.keys = cfg.authorizedKeys ++ globalKeys;
    };
  };
}
