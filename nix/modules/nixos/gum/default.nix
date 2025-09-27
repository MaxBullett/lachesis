{ config, lib, options, pkgs, ... }:
let
  inherit (lib) concatStringsSep mapAttrsToList mkEnableOption mkIf;
  cfg = config.gum;
  # Catppuccin Macchiato palette
  palette = {
    base      = "#24273a"; # Base
    text      = "#cad3f5"; # Text
    subtext0  = "#a5adcb"; # Subtext0
    overlay0  = "#6e738d"; # Overlay0 (nice for borders)
    # surface0  = "#363a4f"; # Not used in wrapper but kept for reference
  };

  themedEnv = {
    GUM_STYLE_FOREGROUND = palette.text;
    GUM_STYLE_BACKGROUND = palette.base;
    GUM_STYLE_BORDER = "rounded";
    GUM_STYLE_BORDER_FOREGROUND = palette.overlay0;
    GUM_STYLE_MARGIN = "1 2";
    GUM_STYLE_PADDING = "1 2";
    COLORTERM = "truecolor";
  };

  wrapGum = pkgs.gum.overrideAttrs (old: {
    nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ pkgs.makeWrapper ];
    postInstall = (old.postInstall or "") + (
      let flags = concatStringsSep " " (
        mapAttrsToList (n: v: ''--set ${n} "${v}"'') themedEnv
      );
      in ''
        wrapProgram "$out/bin/gum" \
          ${flags}
      ''
    );
  });

in {
  options.gum = {
    enable = mkEnableOption "Enable gum";
  };

  config = (mkIf cfg.enable {
    environment.systemPackages = [ wrapGum ];
  });
}
