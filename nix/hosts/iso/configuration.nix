{ flake, lib, pkgs, modulesPath, ... }:
{
  imports = [
    (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix")
    (modulesPath + "/installer/cd-dvd/channel.nix")
    flake.nixosModules.default
  ];

  networking.hostName = lib.mkDefault (builtins.baseNameOf ./.);

  nix.updates = false;
  nixpkgs.enable = true;
  locale.enable = true;
  time.enable = true;
  disko.enable = true;
  networkmanager.enable = true;
  gum.enable = true;

  isoImage.contents = [
    { source = flake.outPath; target = "/nix-config"; }
  ];

  environment.systemPackages = with pkgs; [
    git curl neovim jq
    (pkgs.writeShellScriptBin "installer" (builtins.readFile ./installer.sh))
  ];

  # Filesystems you’re likely to work with during install
  boot.supportedFilesystems = [ "btrfs" "ext4" "xfs" "vfat" ];

  # Keep journald light on the ISO
  services.journald.extraConfig = ''
    Storage=volatile
  '';

  system.stateVersion = "25.05";
}
