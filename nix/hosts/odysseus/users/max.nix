{ flake, pkgs, ... }:
{
  imports = [
    flake.homeModules.default
  ];

  home = {
    username = "max";
    homeDirectory = "/home/max";
    packages = with pkgs; [
      ripgrep
      fd
      unzip
      jetbrains.idea-ultimate
      jetbrains.dataspell
      rclone
      borgbackup
    ];
  };

  lachesis = {
    impermanence = {
      preserve = {
        directories = [
          ".ssh"
          ".gnupg"
          "Code"
          "Documents"
          "Pictures"
          "Music"
          "Videos"
          "Projects"
          "Work"
          ".mozilla"
          ".config/cosmic"
          ".config/git"
          ".config/JetBrains"
        ];
        files = [];
      };
      persist = {
        directories = [
          "Downloads"
        ];
        files = [ ];
      };
    };
    direnv.enable = true;
    steam.enable = true;
  };

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    initContent = ''
      eval "$(starship init zsh)"
      eval "$(direnv hook zsh)"
    '';
  };
  programs.git = {
    enable = true;
    userName = "Max Bullett";
    userEmail = "31956266+MaxBullett@users.noreply.github.com";
    extraConfig = {
      gpg.format = "ssh";
      user.signingkey = "/home/max/.ssh/id_ed25519.pub";
      commit.gpgsign = true;
      gpg.ssh.allowedSignersFile = "/home/max/.ssh/allowed_signers";
    };
  };

  home.stateVersion = "25.05";
}
