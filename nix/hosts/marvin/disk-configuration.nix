{ lib, ... }:
let
  defaultDisk = "nvme-eui.000000000000000100a075213332eac0";
  byId = builtins.getEnv "DISK_BY_ID";
    d = builtins.getEnv "DISK";
    disk = if byId != "" then "/dev/disk/by-id/${byId}"
           else if d != "" then d
           else "/dev/disk/by-id/${defaultDisk}";
in {
  disko.devices.disk.nvme0n1 = {
    type = "disk";
    device = lib.mkDefault disk;
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          priority = 1;
          name = "ESP";
          size = "512M";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [
              "umask=0077"
            ];
          };
        };
        luks = {
          name = "luks";
          priority = 2;
          size = "100%";
          content = {
            type = "luks";
            name = "cryptroot";
            settings = {
              allowDiscards = true;
            };
            content = {
              type = "lvm_pv";
              vg = "vg0";
            };
          };
        };
      };
    };
  };

  disko.devices.lvm_vg.vg0 = {
    type = "lvm_vg";
    lvs = {
      swap = {
        size = "40G";
        content = {
          type = "swap";
        };
      };
      root = {
        size = "100%FREE";
        content = {
          type = "btrfs";
          extraArgs = [ "-f" ];
          subvolumes = {
            "@purge" = {
              mountpoint = "/";
              mountOptions = [ "compress=zstd" "ssd" "discard=async" "noatime" ];
            };
            "@persist" = {
              mountpoint = "/persist";
              mountOptions = [ "compress=zstd" "ssd" "discard=async" "noatime" ];
            };
            "@preserve" = {
              mountpoint = "/preserve";
              mountOptions = [ "compress=zstd" "ssd" "discard=async" "noatime" ];
            };
            "@nix" = {
              mountpoint = "/nix";
              mountOptions = [ "compress=zstd" "ssd" "discard=async" "noatime" ];
            };
            "@snapshots" = {
              mountpoint = "/.snapshots";
              mountOptions = [ "compress=zstd" "ssd" "discard=async" "noatime" ];
            };
          };
        };
      };
    };
  };
}
