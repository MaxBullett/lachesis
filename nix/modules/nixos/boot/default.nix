{ config, lib, ... }:
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
  };

  config = mkIf cfg.enable {
    boot.loader = {
      systemd-boot = {
        enable = true;
        configurationLimit = 10;
        consoleMode = "auto";
      };
      efi.canTouchEfiVariables = true;
      timeout = mkDefault 5;
    };
  };
}
