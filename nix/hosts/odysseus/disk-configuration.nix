{ ... }:
let
  nvme0n1 = "nvme-eui.000000000000000100a075213332eac0";
  defaultBtrfsOpts = [
    "compress=zstd:1"
    "discard=async"
    "noatime"
  ];
in {
  disko.devices = {
    disk = {
      "nvme0n1" = {
        type = "disk";
        device = "/dev/disk/by-id/${nvme0n1}";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "512M";
              type = "EF00";
              content = {
                format = "vfat";
                mountOptions = [ "umask=0077" ];
                mountpoint = "/boot";
                type = "filesystem";
              };
            };
            luks = {
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
    };

    lvm_vg = {
      vg0 = {
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
                  mountOptions = defaultBtrfsOpts;
                };
                "@persist" = {
                  mountpoint = "/persist";
                  mountOptions = defaultBtrfsOpts;
                };
                "@preserve" = {
                  mountpoint = "/preserve";
                  mountOptions = defaultBtrfsOpts;
                };
                "@nix" = {
                  mountpoint = "/nix";
                  mountOptions = defaultBtrfsOpts;
                };
                "@snapshots" = {
                  mountpoint = "/.snapshots";
                  mountOptions = defaultBtrfsOpts;
                };
              };
            };
          };
        };
      };
    };
  };
}
