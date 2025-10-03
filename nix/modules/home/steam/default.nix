{ config, lib, ... }:
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.steam;
in {
  options.steam = {
    enable = mkEnableOption "Enable steam";
  };
  config = mkIf cfg.enable {
    userImpermanence.persist.directories = [
      ".local/share/Steam"
    ];
  };
}
