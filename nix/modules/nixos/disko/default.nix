{ config, inputs, lib, pkgs, ... }:
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.lachesis.disko;
in {
  imports = [ inputs.disko.nixosModules.disko ];

  options.lachesis.disko = {
    enable = mkEnableOption "Declarative disk partitioning with disko";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ pkgs.disko ];
  };
}
