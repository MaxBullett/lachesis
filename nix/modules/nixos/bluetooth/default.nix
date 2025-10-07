{ config, lib, ... }:
let
  inherit (lib) mkEnableOption mkIf mkOption types;
  cfg = config.lachesis.bluetooth;
in {
  options.lachesis.bluetooth = {
    enable = mkEnableOption "Enable Bluetooth";
    experimental = mkOption {
      type = types.bool;
      default = false;
      description = "Enable BlueZ experimental features (sets `General.Experimental = true`).";
    };
    powerOnBoot = mkOption {
      type = types.bool;
      default = true;
      description = "Forwarded to `hardware.bluetooth.powerOnBoot`.";
    };
  };

  config = (mkIf cfg.enable {
    hardware.bluetooth = {
      enable = true;
      inherit (cfg) powerOnBoot;
      settings = mkIf cfg.experimental {
        General.Experimental = true;
      };
    };
    lachesis.impermanence.persist.directories = [ "/var/lib/bluetooth" ];
  });
}
