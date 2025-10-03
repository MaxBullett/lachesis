{ config, lib, options, ... }:
let
  inherit (lib) mkEnableOption mkIf mkIfOptionEnabled mkOption types;
  cfg = config.bluetooth;
in {
  options.bluetooth = {
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
      powerOnBoot = cfg.powerOnBoot;
      settings = mkIf cfg.experimental {
        General.Experimental = true;
      };
    };
  })
  // (mkIf cfg.enable (mkIfOptionEnabled [ "impermanence" "enable" ] options config {
    impermanence.persist.directories = [
      { directory = "/var/lib/bluetooth"; user = "root"; group = "root"; mode = "0700"; }
    ];
  }));
}
