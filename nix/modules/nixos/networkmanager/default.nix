{ config, flake, lib, options, ... }:
let
  inherit (lib) mkEnableOption mkIf mkOption optionalAttrs types;
  inherit (flake.lib) mkIfOptionEnabled;
  cfg = config.networkmanager;
in {
  options.networkmanager = {
    enable = mkEnableOption "Enable NetworkManager";

    wifiBackend = mkOption {
      type = types.enum [ "wpa_supplicant" "iwd" ];
      default = "wpa_supplicant";
      description = "Wi-Fi backend used by NetworkManager.";
    };

    wifiPowerSave = mkOption {
      type = types.bool;
      default = false;
      description = "Enable Wi-Fi powersave via NetworkManager.";
    };
  };

  config = (mkIf cfg.enable {
    networking = {
      networkmanager = {
        enable = true;
        wifi = {
          backend = cfg.wifiBackend;
          powersave = cfg.wifiPowerSave;
        };
      };
    }
    // optionalAttrs (cfg.wifiBackend == "iwd") {
      wireless.iwd.enable = true;
    };
  })
  // (mkIf cfg.enable (mkIfOptionEnabled [ "impermanence" "enable" ] options config {
    impermanence.persist.directories = [
      { directory = "/etc/NetworkManager/system-connections"; user = "root"; group = "root"; mode = "0700"; }
      { directory = "/var/lib/NetworkManager"; user = "root"; group = "root"; mode = "0700"; }
    ];
  }));
}
