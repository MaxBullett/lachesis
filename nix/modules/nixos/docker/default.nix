{ config, lib, options, pkgs, ... }:
let
  inherit (lib)
    any
    attrNames
    attrValues
    filterNormalUsers
    filterSudoUsers
    mkAfter
    mkEnableOption
    mkIf
    mkIfOptionEnabled;
  cfg = config.lachesis.docker;
in {
  options.lachesis.docker = {
    enable = mkEnableOption "Enable Docker";
  };

  config = (mkIf cfg.enable {
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
      members = mkAfter (attrNames (filterSudoUsers (filterNormalUsers config.users.users)));
    };

    environment.systemPackages = [ pkgs.docker-compose ];
  })
  // (mkIf cfg.enable (mkIfOptionEnabled [ "impermanence" "enable" ] options.lachesis config {
    lachesis.impermanence.persist.directories = [
      { directory = "/var/lib/docker"; user = "root"; group = "root"; mode = "0710"; }
    ];
  }));
}
