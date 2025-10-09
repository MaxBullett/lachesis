{ config, lib, pkgs, ... }:
let
  inherit (lib)
    any
    attrValues
    filterSudoUsers
    mkAfter
    mkEnableOption
    mkIf;
  cfg = config.lachesis.docker;
in {
  options.lachesis.docker = {
    enable = mkEnableOption "Enable Docker";
  };

  config = (mkIf cfg.enable {
    environment.systemPackages = [ pkgs.docker-compose ];

    virtualisation = {
      docker = {
        enable = true;
        storageDriver = if any (fs: fs.fsType == "btrfs") (attrValues config.fileSystems)
                        then "btrfs"
                        else "overlay2";
        autoPrune = {
          enable = true;
          dates = "weekly";
          flags = [ "--all" "--volumes" ];
        };
      };
      oci-containers.backend = "docker";
    };

    users.groups.docker = {
      members = mkAfter (filterSudoUsers config.users.users);
    };

    lachesis.preservation.persist.directories = [ "/var/lib/docker" ];
  });
}
