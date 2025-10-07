{ config, lib, pkgs, ... }:
let
  inherit (lib) mkDefault mkIf mkOption types;
  cfg = config.lachesis.boot;
in {
  options.lachesis.boot = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Enable systemd-boot defaults provided by this module.";
    };
    kernelParams = mkOption {
      type = with types; listOf str;
      default = [];
      description = "Extra kernel command line parameters to append to boot.kernelParams.";
    };
  };

  config = mkIf cfg.enable {
    boot = {
      kernelPackages = pkgs.linuxPackages_latest;
      inherit (cfg) kernelParams;
      initrd.systemd.enable = true;
      loader = {
        efi.canTouchEfiVariables = true;
        timeout = mkDefault 5;
        systemd-boot = {
          enable = true;
          configurationLimit = 10;
          consoleMode = "auto";
        };
      };
    };
  };
}
