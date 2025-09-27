{ config, lib, ... }:
let
  inherit (lib) mkEnableOption mkIf mkOption types;
  cfg = config.cosmic;
in {
  options.cosmic = {
    enable = mkEnableOption "COSMIC desktop environment";
    greeter = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable the COSMIC greeter (display manager).";
      };
    };
    xwayland = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable XWayland support for COSMIC.";
      };
    };
    autoLogin = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable auto login for the greeter.";
      };
      user = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Username to auto login as when autoLogin is enabled.";
      };
    };
  };

  config = mkIf cfg.enable  {
    assertions = [
      {
        assertion = !(cfg.enable && cfg.autoLogin.enable)
          || (cfg.autoLogin.user != null && cfg.autoLogin.user != "");
        message = "cosmic.autoLogin.user must be set when cosmic.autoLogin.enable = true.";
      }
    ];

    services.displayManager = {
      cosmic-greeter.enable = cfg.greeter.enable;
      autoLogin = mkIf cfg.autoLogin.enable {
        enable = true;
        user = cfg.autoLogin.user;
      };
    };
    services.desktopManager.cosmic = {
      enable = true;
      xwayland.enable = cfg.xwayland.enable;
    };
  };
}
