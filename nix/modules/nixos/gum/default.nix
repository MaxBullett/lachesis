{ config, lib, pkgs, ... }:
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.gum;

in {
  options.gum = {
    enable = mkEnableOption "Enable gum";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ pkgs.gum ];
  };
}
