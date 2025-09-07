{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  networking.hostName = "marvin";

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  time.timeZone = "Europe/Berlin";
  i18n.defaultLocale = "en_US.UTF-8";

  # Kernel
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Bootloader + LUKS resume
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.resumeDevice = "/dev/mapper/cryptroot";
  boot.kernelParams = [ "resume_offset=1068547" ];

  # Networking
  networking.networkmanager.enable = true;

  # User
  users.users.max = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "audio" "video" ];
  };

  # Swap
  swapDevices = [
    { device = "/swap/swapfile"; }
  ];
  zramSwap = {
    enable = true;
    memoryPercent = 10;
    priority = 100;
  };

  # Desktop
  services.displayManager.cosmic-greeter.enable = true;
  services.desktopManager.cosmic.enable = true;

  # Apps
  programs.firefox.enable = true;
  programs.neovim = {
    enable = true;
    defaultEditor = true;
  };

  environment.systemPackages = with pkgs; [
    curl git openssh vim wget
  ];

  system.stateVersion = "25.05";
}

