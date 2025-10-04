{ config, lib, ... }:
let
  inherit (lib) mkEnableOption mkIf mkOption types;
  cfg = config.lachesis.time;
in {
  options.lachesis.time = {
    enable = mkEnableOption "Enable time configuration defaults";

    defaultTimeZone = mkOption {
      type = types.str;
      default = "Europe/Berlin";
      description = "System timezone (e.g., Europe/Berlin).";
    };
  };

  config = mkIf cfg.enable {
    time.timeZone = cfg.defaultTimeZone;
    services.timesyncd = {
      enable = true;
      servers = [ "time.cloudflare.com" "pool.ntp.org" ];
    };
  };
}
