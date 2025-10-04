{ config, lib, options, ... }:
let
  inherit (lib) mkEnableOption mkIf mkIfOptionEnabled;
  cfg = config.lachesis.__NAME__;
in {
  options.lachesis.__NAME__ = {
    enable = mkEnableOption "Enable __NAME__ module";
  };

  imports = [];

  assertions = [];
  warnings = [];

  config = (mkIf cfg.enable {})
  # Conditional config, applied only when enabled and target condition met
  // (mkIf cfg.enable (mkIfOptionEnabled [ "impermanence" "enable" ] options.lachesis config {
    lachesis.impermanence.persist.directories = [];
  }));
}
