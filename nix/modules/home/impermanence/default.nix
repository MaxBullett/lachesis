{ config, inputs, lib, ... }:
let
  inherit (lib) mkEnableOption mkIf mkOption types;
  cfg = config.userImpermanence;
  username = config.home.username or (throw "home.username must be set before importing home.modules.impermanence");
in {
  imports = [ inputs.impermanence.homeManagerModules.impermanence ];

  options.userImpermanence = {
    enable = mkEnableOption "impermanence with dual persistent roots (/persist and /preserve)";
    persist = {
      path = mkOption {
        type = types.str;
        default = "/persist";
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
        default = "/preserve";
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

  config = mkIf cfg.enable {
    # Map to HM impermanence roots
    home.persistence."${cfg.preserve.path}/home/${username}" = {
      allowOther = true;
      directories = cfg.preserve.directories;
      files = cfg.preserve.files;
    };
    home.persistence."${cfg.persist.path}/home/${username}" = {
      allowOther = true;
      directories = cfg.persist.directories;
      files = cfg.persist.files;
    };
  };
}
