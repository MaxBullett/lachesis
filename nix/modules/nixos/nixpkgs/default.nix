{ config, lib, ... }:
let
  inherit (lib) mkDefault mkEnableOption mkIf;
  cfg = config.nixpkgs;
in {
  options.nixpkgs = {
    enable = mkEnableOption "Enable nixpkgs defaults";
  };

  config = mkIf cfg.enable {
    nixpkgs = {
      config.allowUnfree = true;
      hostPlatform = mkDefault "x86_64-linux";
    };
  };
}
