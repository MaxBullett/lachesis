{ pkgs, ... }:
pkgs.mkShell {
  buildInputs = with pkgs; [
    deadnix
    git
    nixd
    nixfmt-rfc-style
    statix
    tmux
    vim
  ];

  shellHook = ''
    echo "Welcome to the devshell."
    export EDITOR=vim
  '';
}
