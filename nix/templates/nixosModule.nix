{ config, lib, ... }:
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.lachesis.__NAME__;
in {
  options.lachesis.__NAME__ = {
    enable = mkEnableOption "Enable __NAME__ module";
  };

  imports = [];

  assertions = [];
  warnings = [];

  config = (mkIf cfg.enable {});
}
