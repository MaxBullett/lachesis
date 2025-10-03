{ config, lib, pkgs, ... }:
let
  inherit (lib) anyUser mkIf;
  enable = anyUser config (user: user.steam.enable);
in {
  config = mkIf enable {
    programs.steam = {
      enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
    };
    programs.gamemode.enable = true;
    programs.steam.extraCompatPackages = with pkgs; [
      proton-ge-bin
    ];
  };
}
