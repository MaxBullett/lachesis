{ config, lib, pkgs, ... }:
let
  inherit (lib) mkEnableOption mkIf mkOption types;
  cfg = config.lachesis.plymouth;
in {
  options.lachesis.plymouth = {
    enable = mkEnableOption "Enable Plymouth splash during boot";

    themePackages = mkOption {
      type = with types; listOf package;
      default = with pkgs; [ catppuccin-plymouth ];
      description = "Packages providing Plymouth themes.";
    };

    theme = mkOption {
      type = types.str;
      default = "catppuccin-macchiato";
      description = "Selected Plymouth theme name.";
    };
  };

  config = mkIf cfg.enable {
    boot = {
      plymouth = {
        enable = true;
        inherit (cfg) themePackages;
        inherit (cfg) theme;
      };

      kernelParams = [
        "quiet"
        "splash"
        "plymouth.use-simpledrm"
        "loglevel=3"
        "systemd.show_status=auto"
        "udev.log_level=3"
        "rd.udev.log_level=3"
        "vt.global_cursor_default=0"
      ];
      consoleLogLevel = 0;
      initrd.verbose = false;
      loader.timeout = 0;
    };

    console.earlySetup = false;
  };
}
