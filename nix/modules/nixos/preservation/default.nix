{ config, inputs, lib, pkgs, ... }:
let
  inherit (lib) mapAttrs mkEnableOption mkIf mkOption types;
  users = config.home-manager.users or {};
  rootDevice = config.fileSystems."/";
  cfg = config.lachesis.preservation;
in
{
  options.lachesis.preservation = {
    enable = mkEnableOption "Enable preservation with ephemeral root, persist, and preserve";
    persist = {
      path = mkOption {
        type = types.str;
        default = "/persist";
        description = "Root for persisted but not backed up data";
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
        description = "Root for persisted and backed up data";
      };
      directories = mkOption {
        type = with types; listOf (either str attrs);
        default = [];
        description = "System directories persisted after reboot and backed up";
      };
      files = mkOption {
        type = with types; listOf (either str attrs);
        default = [];
        description = "System files persisted after reboot and backed up";
      };
    };
  };

  imports = [ inputs.preservation.nixosModules.default ];

  config =  mkIf cfg.enable {
    preservation = {
      inherit (cfg) enable;

      preserveAt = {
        # Persists boot
        "${cfg.persist.path}" = {
          directories = [
            "/etc/ssh"
            {
              directory = "/var/lib/nixos";
              inInitrd = true;
            }
            {
              directory = "/var/lib/private";
              mode = "0700";
            }
            "/var/lib/systemd"
            "/var/log"
          ] ++ cfg.persist.directories;

          files = [
            {
              file = "/etc/machine-id";
              mode = "0444";
              how = "symlink";
              inInitrd = true;
            }
            {
              file = "/var/lib/logrotate.status";
              mode = "0600";
              how = "symlink";
            }
          ] ++ cfg.persist.files;

          users = mapAttrs (_: user: {
            commonMountOptions = [
              "x-gvfs-hide"
            ];
            inherit (user.lachesis.preservation.persist) directories;
            inherit (user.lachesis.preservation.persist) files;
          }) users;
        };

        # Persists boot and is backed up
        "${cfg.preserve.path}" = {
          inherit (cfg.preserve) directories;
          inherit (cfg.preserve) files;

          users = mapAttrs (_: user: {
            commonMountOptions = [
              "x-gvfs-hide"
            ];
            inherit (user.lachesis.preservation.preserve) directories;
            inherit (user.lachesis.preservation.preserve) files;
          }) users;
        };
      };
    };

    fileSystems."/nix".neededForBoot = true;
    fileSystems.${cfg.persist.path}.neededForBoot = true;
    fileSystems.${cfg.preserve.path}.neededForBoot = true;

    # systemd-machine-id-commit.service would fail but it is not relevant
    # let the service commit the transient ID to the persistent volume
    systemd.suppressedSystemUnits = [ "systemd-machine-id-commit.service" ];
    systemd.services.systemd-machine-id-commit = {
      unitConfig.ConditionPathIsMountPoint = [
        ""
        "${cfg.persist.path}/etc/machine-id"
      ];
      serviceConfig.ExecStart = [
        ""
        "systemd-machine-id-setup --commit --root ${cfg.persist.path}"
      ];
    };


    assertions = [
      {
        assertion = rootDevice.fsType == "btrfs";
        message = "persistence requires btrfs filesystem";
      }
    ];
    boot.initrd.systemd = {
      emergencyAccess = true;
      services.purge-root = {
        description = "Purge the root subvolume.";
        wantedBy = [ "initrd.target" ];
        before = [ "sysroot.mount" ];
        requires = [ "initrd-root-device.target" ];
        after = [ "initrd-root-device.target" ];
        unitConfig.DefaultDependencies = "no";
        serviceConfig.Type = "oneshot";
        path = with pkgs; [
          btrfs-progs
        ];
        script = ''
          set -euo pipefail
          export PATH="$PATH:/bin"

          echo "Mounting root"
          MNTPOINT=$(mktemp -d)
          mount -o subvol=/ ${rootDevice.device} $MNTPOINT
          trap 'umount $MNTPOINT; rm -d $MNTPOINT' EXIT

          echo "Purging root"
          btrfs subvolume delete -R $MNTPOINT/@purge

          echo "Restoring root"
          btrfs subvolume snapshot $MNTPOINT/@snapshots/purge-blank $MNTPOINT/@purge
        '';
      };
    };
  };
}
