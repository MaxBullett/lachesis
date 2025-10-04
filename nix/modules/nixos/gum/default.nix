{ config, lib, pkgs, ... }:
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.lachesis.gum;

in {
  options.lachesis.gum = {
    enable = mkEnableOption "Enable gum";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ pkgs.gum ];
  };
}
