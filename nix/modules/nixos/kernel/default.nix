{ config, lib, pkgs, ... }:
let
  inherit (lib) mkEnableOption mkIf mkOption types;
  cfg = config.lachesis.kernel;
in {
  options.lachesis.kernel = {
    enable = mkEnableOption "Enable kernel configuration defaults";
    kernelParams = mkOption {
      type = with types; listOf str;
      default = [];
      description = "Extra kernel command line parameters to append to boot.kernelParams.";
    };
  };

  config = mkIf cfg.enable {
    boot = {
      kernelPackages = pkgs.linuxPackages_latest;
      initrd.systemd.enable = true;
      inherit (cfg) kernelParams;
    };
  };
}
