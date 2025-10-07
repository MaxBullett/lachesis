{ config, lib, ... }:
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.lachesis.steam;
in {
  options.lachesis.steam = {
    enable = mkEnableOption "Enable steam";
  };
  config = mkIf cfg.enable {
    lachesis.preservation.persist.directories = [ ".local/share/Steam" ".steam" ];
  };
}
