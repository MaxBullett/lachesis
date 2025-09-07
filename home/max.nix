{ pkgs, ... }:
{
  home.username = "max";
  home.homeDirectory = "/home/max";

  programs.zsh.enable = true;

  programs.git = {
    enable = true;
    userName = "Max Bullett";
    userEmail = "31956266+MaxBullett@users.noreply.github.com";
    extraConfig = {
      gpg.format = "ssh";
      user.signingkey = "~/.ssh/id_ed25519.pub";
      commit.gpgsign = true;
      gpg.ssh.allowedSignersFile = "~/.ssh/allowed_signers";
    };
  };

  home.packages = with pkgs; [
    ripgrep fd unzip
  ];

  home.stateVersion = "25.05";
}

