{ config, inputs, lib, ... }:
let
  inherit (lib)
    escapeShellArg
    mapAttrs
    mkBefore
    mkEnableOption
    mkIf
    mkOption
    types;
  rootDevice = config.fileSystems."/".device or (throw "Root filesystem must specify its device for impermanence");
  users = config.home-manager.users or {};
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

    # Ensure persistent roots exist at boot
    fileSystems.${cfg.persist.path}.neededForBoot = true;
    fileSystems.${cfg.preserve.path}.neededForBoot = true;

    # Script to wipe the root subvolume at boot
    boot.initrd.systemd.services.lachesis-restore-root = {
      description = "Restore blank @purge subvolume";
      wantedBy = [ "sysroot.mount" ];
      before = [ "sysroot.mount" ];
      after = [ "initrd-root-device.target" ];
      requires = [ "initrd-root-device.target" ];
      unitConfig.DefaultDependencies = "no";
      serviceConfig.Type = "oneshot";
      script = ''
        set -euo pipefail

        mkdir -p /mnt
        mount -t btrfs -o subvolid=5 ${escapeShellArg rootDevice} /mnt

        if btrfs subvolume show /mnt/@purge &>/dev/null; then
          btrfs subvolume list -o /mnt/@purge |
          cut -f9 -d' ' |
          while read subvolume; do
            echo "Deleting /$subvolume subvolume."
            btrfs subvolume delete "/mnt/$subvolume"
          done

          echo "Deleting /@purge subvolume."
          btrfs subvolume delete /mnt/@purge
        fi

        if [ ! -e /mnt/@snapshots/purge-blank ]; then
          echo "Missing purge-blank snapshot, dropping to emergency shell." >&2
          exit 1
        fi

        echo "Restoring blank /@purge subvolume..."
        btrfs subvolume snapshot /mnt/@snapshots/purge-blank /mnt/@purge

        umount /mnt
      '';
    };

    environment.persistence = {
      # Persisted directories and files
      "${cfg.persist.path}" = {
        hideMounts = true;
        # System
        directories = [
          "/var/lib/systemd/coredump"
          "/var/lib/systemd/timers"
          "/var/log"
        ] ++ cfg.persist.directories;
        files = [
          "/etc/machine-id"
          "/etc/shadow" # TODO: Remove when declarative setup complete
          "/etc/ssh/ssh_host_ed25519_key"
          "/etc/ssh/ssh_host_ed25519_key.pub"
          "/etc/ssh/ssh_host_rsa_key"
          "/etc/ssh/ssh_host_rsa_key.pub"
        ] ++ cfg.persist.files;

        # User
        users = mapAttrs (_: user: {
          directories = user.lachesis.impermanence.persist.directories;
          files = user.lachesis.impermanence.persist.files;
        }) users;
      };

      # Preserved directories and files (persisted and snapshot)
      "${cfg.preserve.path}" = {
        hideMounts = true;
        # System
        directories = [
          "/etc/nixos"
          "/var/lib/nixos"
        ] ++ cfg.preserve.directories;
        files = [
        ] ++ cfg.preserve.files;

        # User
        users = mapAttrs (_: user: {
          directories = user.lachesis.impermanence.preserve.directories;
          files = user.lachesis.impermanence.preserve.files;
        }) users;
      };
    };

    # Make journald persistent under /persist
    services.journald.storage = "persistent";
  };
}
