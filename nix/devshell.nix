{ pkgs, ... }:
pkgs.mkShell {
  buildInputs = with pkgs; [
    git
    vim
    tmux
    nixfmt-rfc-style
  ];

  shellHook = ''
    echo "Welcome to the devshell."
    export EDITOR=vim
  '';
}
