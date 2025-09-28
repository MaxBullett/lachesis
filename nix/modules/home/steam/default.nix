{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.steam;
in {
  options.steam = {
    enable = mkEnableOption "Steam gaming client for the user";
  };

  config = mkIf cfg.enable {
    # Install Steam for the user via Home Manager
    home.packages = [ pkgs.steam ];

    # Ensure Steam game files persist across reboots on impermanent systems.
    # This integrates with the existing userImpermanence module if imported.
    userImpermanence.persist.directories = [
      ".local/share/Steam"
    ];
  };
}
