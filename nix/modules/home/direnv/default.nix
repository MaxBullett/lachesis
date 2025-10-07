{ config, lib, ... }:
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.lachesis.direnv;
in {
  options.lachesis.direnv = {
    enable = mkEnableOption "Enable direnv";
  };
  config = mkIf cfg.enable {
    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
      config= {
        global = {
          load_dotenv = true;
          strict_env = true;
        };
        whitelist.prefix = [
          "/etc/nixos"
          "${config.home.homeDirectory}/Code"
          "${config.home.homeDirectory}/Work"
        ];
      };
    };
    lachesis.impermanence.persist.directories = [ ".local/share/direnv" ];
  };
}
