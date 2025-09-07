{ pkgs, ... }:
{
  home.username = "max";
  home.homeDirectory = "/home/max";

  programs.zsh.enable = true;

  programs.git = {
    enable = true;
    userName = "Max";
    userEmail = "31956266+MaxBullett@users.noreply.github.com";
  };

  home.packages = with pkgs; [
    ripgrep fd unzip
  ];

  home.stateVersion = "25.05";
}

