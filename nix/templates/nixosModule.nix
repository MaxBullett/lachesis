{ config, lib, options, ... }:
let
  inherit (lib) mkEnableOption mkIf mkIfOptionEnabled;
  cfg = config.__NAME__;
in {
  options.__NAME__ = {
    enable = mkEnableOption "Enable __NAME__ module";
  };

  imports = [];

  assertions = [];
  warnings = [];

  config = (mkIf cfg.enable {})
  # Conditional config, applied only when enabled and target condition met
  // (mkIf cfg.enable (mkIfOptionEnabled [ "impermanence" "enable" ] options config {
    impermanence.persist.directories = [];
  }));
}
