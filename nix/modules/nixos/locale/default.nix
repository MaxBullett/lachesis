{ config, lib, ... }:
let
  inherit (lib) mkEnableOption mkIf mkOption optionalAttrs types;
  cfg = config.lachesis.locale;
in {
  options.lachesis.locale = {
    enable = mkEnableOption "Enable locale settings (i18n and console)";

    defaultLocale = mkOption {
      type = types.str;
      default = "en_IE.UTF-8";
      description = "Default locale (forwarded to i18n.defaultLocale).";
    };

    keyMap = mkOption {
      type = types.str;
      default = "us";
      description = "Console keymap (forwarded to console.keyMap).";
    };

    supportedLocales = mkOption {
      type = with types; listOf str;
      default = [];
      description = "Locales to generate (forwarded to i18n.supportedLocales). Use glibc format like \"en_US.UTF-8/UTF-8\".";
    };

    extraLocaleSettings = mkOption {
      type = with types; attrsOf str;
      default = {};
      example = { LC_TIME = "en_DK.UTF-8"; };
      description = "Additional LC_* overrides (forwarded to i18n.extraLocaleSettings).";
    };
  };

  config = mkIf cfg.enable {
    i18n = {
      defaultLocale = cfg.defaultLocale;
      extraLocaleSettings = cfg.extraLocaleSettings;
    }
    // (optionalAttrs (cfg.supportedLocales != []) {
      supportedLocales = cfg.supportedLocales;
    });

    console.keyMap = cfg.keyMap;
  };
}
