{ flake, inputs, lib, pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./disk-configuration.nix
    inputs.nixos-hardware.nixosModules.asus-zephyrus-ga402
    flake.nixosModules.default
  ];
  networking.hostName = lib.mkDefault (builtins.baseNameOf ./.);

  nixpkgs.enable = true;
  locale.enable = true;
  time.enable = true;
  boot.enable = true;
  kernel = {
    enable = true;
    kernelParams = [ "amdgpu.dcdebugmask=0x10" ];
  };
  plymouth.enable = true;
  power.enable = true;
  disko.enable = true;
  zramSwap = {
    enable = true;
    memoryPercent = 10;
    priority = 100;
  };
  impermanence.enable = true;
  networkmanager = {
    enable = true;
    wifiBackend = "iwd";
  };
  bluetooth = {
    enable = true;
    experimental = true;
  };
  docker.enable = true;
  gum.enable = true;
  cosmic = {
    enable = true;
    autoLogin = {
      enable = true;
      user = "max";
    };
  };


  users.users.max = {
    isNormalUser = true;
    home = "/home/max";
    extraGroups = [
      "networkmanager"
      "audio"
      "video"
    ];
  };
  users.groups.wheel.members = [ "max" ];
  security.sudo.enable = true;

  # Apps
  programs.firefox.enable = true;
  programs.neovim = {
    enable = true;
    defaultEditor = true;
  };

  security.polkit.enable = true;
  services.gnome.gnome-keyring.enable = true;

  # Firmware + updates
  services.fwupd.enable = true;

  # Pipewire
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };
  # Turn on LC3 in WirePlumber (LE Audio). Optional: disable HW volume if too “steppy”.
  environment.etc."wireplumber/wireplumber.conf.d/10-bluez-lc3.conf".text = ''
    monitor.bluez.properties = {
      bluez5.enable-lc3 = true
      # bluez5.enable-hw-volume = false
    }
  '';

  # USB4/Thunderbolt authorization
  services.hardware.bolt.enable = true;

  # Sensors/monitoring
  environment.systemPackages = with pkgs; [ lm_sensors ];

  # Sleep: GA402RK uses s2idle; don’t force “deep”
  systemd.sleep.extraConfig = ''
    SuspendState=mem
    SuspendMode=
  '';

  # ssh certs
  security.pki.certificates = [
    (builtins.readFile ./daadev-ca.crt)
  ];

  # Debugging
  services.journald.extraConfig = ''
    SystemMaxUse=1G
  '';

  system.stateVersion = "25.05";
}
