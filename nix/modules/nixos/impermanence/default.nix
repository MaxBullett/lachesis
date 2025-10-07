{ config, inputs, lib, pkgs, ... }:
let
  inherit (lib)
    mapAttrs
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

    boot.initrd.systemd = {
      emergencyAccess = true;
      services.rollback = {
        description = "Rollback BTRFS root subvolume to a pristine state";
        wantedBy = [ "initrd.target" ];
        wants = [ "lvm2-activation.service" ];
        after = [ "lvm2-activation.service" "local-fs-pre.target"];
        before = [ "sysroot.mount" ];
        path = with pkgs; [
          btrfs-progs
        ];
        unitConfig = {
          ConditionKernelCommandLine = [ "!resume=" ];
          DefaultDependencies = "no";
          RequiresMountsFor = [ "${rootDevice}" ];
        };
        serviceConfig = {
          StandardOutput = "journal+console";
          StandardError = "journal+console";
          Type = "oneshot";
          UMask = "0077";
        };
        script = ''
          set -euo pipefail

          export PATH="$PATH:/bin"
          mkdir -p /mnt
          echo "Rolling back @purge on ${rootDevice}."
          mount -o subvol=/ "${rootDevice}" /mnt

          while read -r subvolume; do
            echo "Deleting /$subvolume subvolume"
            btrfs subvolume delete "/mnt/$subvolume"
          done < <(
            btrfs subvolume list -o /mnt/@purge |
            cut -d' ' -f9- |
            sort -r
          )

          echo "Deleting /@purge subvolume"
          btrfs subvolume delete /mnt/@purge

          if [[ -d /mnt/@snapshots/purge-blank ]]; then
            echo "Restoring blank /@purge subvolume from template"
            btrfs subvolume snapshot /mnt/@snapshots/purge-blank /mnt/@purge
          else
            echo "Template /@snapshots/purge-blank missing; recreating it"
            btrfs subvolume create /mnt/@purge
            btrfs subvolume snapshot -r /mnt/@purge /mnt/@snapshots/purge-blank
          fi

          umount /mnt
        '';
      };
    };

    # Ensure persistent roots exist at boot
    fileSystems.${cfg.persist.path}.neededForBoot = true;
    fileSystems.${cfg.preserve.path}.neededForBoot = true;

    environment.persistence = {
      # Persisted directories and files
      "${cfg.persist.path}" = {
        hideMounts = true;
        # System
        directories = [
          "/var/lib/btrfs"
          "/var/lib/nixos"
          "/var/lib/systemd"
          "/var/log"
        ] ++ cfg.persist.directories;
        files = [
          "/etc/machine-id"
          "/etc/ssh/ssh_host_ed25519_key"
          "/etc/ssh/ssh_host_ed25519_key.pub"
          "/etc/ssh/ssh_host_rsa_key"
          "/etc/ssh/ssh_host_rsa_key.pub"
          "/var/lib/logrotate.status"
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
