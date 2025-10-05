{ config, inputs, lib, ... }:
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types;
  cfg = config.lachesis.impermanence;
in {
  imports = [ inputs.impermanence.nixosModules.impermanence ];

  options.lachesis.impermanence = {
    enable = mkEnableOption "Enable Impermanence with persist and preserve";
    persist = {
      path = mkOption {
        type = types.str;
        default = "/persist";
        description = "Root for persisted but not snapshot data";
      };
      directories = mkOption {
        type = with types; listOf (either str attrs);
        default = [];
        description = "System directories persisted after reboot";
      };
      files = mkOption {
        type = with types; listOf (either str attrs);
        default = [];
        description = "System files persisted after reboot";
      };
    };
    preserve = {
      path = mkOption {
        type = types.str;
        default = "/preserve";
        description = "Root for persisted and snapshot data";
      };
      directories = mkOption {
        type = with types; listOf (either str attrs);
        default = [];
        description = "System directories persisted after reboot and preserved by snapshot";
      };
      files = mkOption {
        type = with types; listOf (either str attrs);
        default = [];
        description = "System files persisted after reboot and preserved by snapshot";
      };
    };
  };

  config = mkIf cfg.enable {
    # Ensure roots exist at boot
    fileSystems.${cfg.persist.path}.neededForBoot = true;
    fileSystems.${cfg.preserve.path}.neededForBoot = true;

    # Keep tmp clean; root is an ephemeral subvolume (@purge)
    boot.tmp.cleanOnBoot = true;

    # Baseline: sensible system persistence
    # We split system items: minimal essentials go to persist, nothing to preserve by default
    environment.persistence = {
      "${cfg.persist.path}" = {
        hideMounts = true;
        directories = [
          "/etc/nixos"
          "/var/lib/nixos"         # nixos-rebuild state
          "/var/lib/systemd"
          "/var/log/journal"       # journald persistent storage
        ] ++ cfg.persist.directories;
        files = [
          "/etc/machine-id"
          "/etc/ssh/ssh_host_ed25519_key"
          "/etc/ssh/ssh_host_ed25519_key.pub"
          "/etc/ssh/ssh_host_rsa_key"
          "/etc/ssh/ssh_host_rsa_key.pub"
        ] ++ cfg.persist.files;
      };
      "${cfg.preserve.path}" = {
        hideMounts = true;
        inherit (cfg.preserve) directories;
        inherit (cfg.preserve) files;
      };
    };

    # Allows users to allow others on their binds
    programs.fuse.userAllowOther = true;

    # Directory skeletons
    systemd.tmpfiles.rules = [
      "d ${cfg.persist.path} 0755 root root -"
      "d ${cfg.persist.path}/etc 0755 root root -"
      "d ${cfg.persist.path}/var 0755 root root -"
      "d ${cfg.persist.path}/home 0755 root root -"
      "d ${cfg.preserve.path} 0755 root root -"
      "d ${cfg.preserve.path}/etc 0755 root root -"
      "d ${cfg.preserve.path}/var 0755 root root -"
      "d ${cfg.preserve.path}/home 0755 root root -"
    ];

    # Make journald persistent under /persist
    services.journald.storage = "persistent";
  };
}
