{ config, lib, ... }:
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.lachesis.power;
in {
  options.lachesis.power = {
    enable = mkEnableOption "Enable power-profiles-daemon (power management)";
  };

  config = mkIf cfg.enable {
    services.power-profiles-daemon.enable = true;
  };
}
