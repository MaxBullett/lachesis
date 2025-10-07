{ config, lib, ... }:
let
  inherit (lib) mkEnableOption mkIf mkOption optionalAttrs types;
  cfg = config.lachesis.networkmanager;
in {
  options.lachesis.networkmanager = {
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

    lachesis.impermanence.persist.directories = [ "/etc/NetworkManager/system-connections" "/var/lib/NetworkManager" ];
  });
}
