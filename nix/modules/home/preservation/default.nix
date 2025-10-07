{ config, lib, osConfig, ... }:
let
  inherit (lib) mkOption types;
in {
  options.lachesis.preservation = {
    persist = {
      path = mkOption {
        type = types.str;
        default = "${osConfig.lachesis.preservation.persist.path}${config.home.homeDirectory}";
        description = "Root for persisted but not backed up data.";
      };
      directories = mkOption {
        type = with types; listOf (either str attrs);
        default = [];
        description = "Home relative directories persisted after reboot.";
      };
      files = mkOption {
        type = with types; listOf (either str attrs);
        default = [];
        description = "Home relative files persisted after reboot.";
      };
    };
    preserve = {
      path = mkOption {
        type = types.str;
        default = "${osConfig.lachesis.preservation.preserve.path}${config.home.homeDirectory}";
        description = "Root for persisted and backed up data.";
      };
      directories = mkOption {
        type = with types; listOf (either str attrs);
        default = [];
        description = "Home relative directories persisted after reboot and backed up.";
      };
      files = mkOption {
        type = with types; listOf (either str attrs);
        default = [];
        description = "Home relative files persisted after reboot and backed up.";
      };
    };
  };
}
