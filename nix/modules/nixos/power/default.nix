{ config, lib, ... }:
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.power;
in {
  options.power = {
    enable = mkEnableOption "Enable power-profiles-daemon (power management)";
  };

  config = mkIf cfg.enable {
    services.power-profiles-daemon.enable = true;
  };
}
