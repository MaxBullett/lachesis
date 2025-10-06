{ config, lib, osConfig, ... }:
let
  inherit (lib) mkOption types;
in {
  options.lachesis.impermanence = {
    persist = {
      path = mkOption {
        type = types.str;
        default = "${osConfig.lachesis.impermanence.persist.path}${config.home.homeDirectory}";
        description = "Root for persisted but not snapshot data.";
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
        default = "${osConfig.lachesis.impermanence.preserve.path}${config.home.homeDirectory}";
        description = "Root for persisted and snapshot data.";
      };
      directories = mkOption {
        type = with types; listOf (either str attrs);
        default = [];
        description = "Home relative directories persisted after reboot and preserved by snapshot.";
      };
      files = mkOption {
        type = with types; listOf (either str attrs);
        default = [];
        description = "Home relative files persisted after reboot and preserved by snapshot.";
      };
    };
  };
}
