{ config, lib, ... }:
let
  inherit (lib) mkIf mkOption types;
  cfg = config.lachesis.nix;
in {
  options.lachesis.nix = {
    extraSubstituters = mkOption {
      type = with types; listOf str;
      default = [];
      description = "Additional substituters to append to nix.settings.substituters";
    };

    extraTrustedPublicKeys = mkOption {
      type = with types; listOf str;
      default = [];
      description = "Additional cache public keys to append to nix.settings.trusted-public-keys";
    };

    nh  = mkOption {
      type = types.bool;
      default = true;
      description = "Enable programs.nh";
    };

    updates = mkOption {
      type = types.bool;
      default = true;
      description = "Enable system.autoUpgrade";
    };
  };

  config = {
    nix.settings = {
      experimental-features = [ "nix-command" "flakes" ];
      download-buffer-size = 524288000; #500MB
      auto-optimise-store = true;
      trusted-users = [ "root" "@wheel" ];
      warn-dirty = false;
      builders-use-substitutes = true;
      substituters = [
        "https://cache.nixos.org"
        "https://nix-community.cachix.org"
        "https://maxbullett.cachix.org"
      ] ++ cfg.extraSubstituters;
      trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "maxbullett.cachix.org-1:/6uBIAw06/eUnFR/UTgTk4w9ZfSAtrf3a1R9aOkpixY="
      ] ++ cfg.extraTrustedPublicKeys;
      require-sigs = true;
    };

    programs.nh = mkIf cfg.nh {
      enable = true;
      flake = "/etc/nixos";
      clean = {
        enable = true;
        extraArgs = "--keep-since 1w --keep 5";
      };
    };

    system.autoUpgrade = mkIf cfg.updates {
      enable = true;
      flake = "/etc/nixos#${config.networking.hostName}";
      dates = "daily";
      randomizedDelaySec = "30min";
      allowReboot = false;
    };
  };
}
