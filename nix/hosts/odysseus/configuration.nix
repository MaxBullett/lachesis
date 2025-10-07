{ flake, inputs, lib, pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./disk-configuration.nix
    inputs.nixos-hardware.nixosModules.asus-zephyrus-ga402
    flake.nixosModules.default
  ];
  networking.hostName = lib.mkDefault (builtins.baseNameOf ./.);

  lachesis = {
    nixpkgs.enable = true;
    locale.enable = true;
    time.enable = true;
    boot = {
      enable = true;
      kernelParams = [];
    };
    plymouth.enable = true;
    power.enable = true;
    disko.enable = true;
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
  };

  zramSwap = {
    enable = true;
    memoryPercent = 10;
    priority = 100;
  };

  users.users.max = {
    initialPassword = "password";
    isNormalUser = true;
    home = "/home/max";
    extraGroups = [
      "networkmanager"
      "audio"
      "video"
    ];
  };
  users.groups.wheel.members = [ "max" ];

  security = {
    sudo.enable = true;
    polkit.enable = true;
    pki.certificates = [
        #(builtins.readFile ./daadev-ca.crt)
    ];
  };

  # Apps
  programs = {
    firefox.enable = true;
    neovim = {
      enable = true;
      defaultEditor = true;
    };
  };
  services = {
    gnome.gnome-keyring.enable = true;
    fwupd.enable = true;
    pipewire = {
      enable = true;
      alsa.enable = true;
      pulse.enable = true;
      wireplumber.enable = true;
    };
    hardware.bolt.enable = true;
    journald.extraConfig = ''
        SystemMaxUse=1G
      '';
  };
  # Turn on LC3 in WirePlumber (LE Audio). Optional: disable HW volume if too “steppy”.
  environment.etc."wireplumber/wireplumber.conf.d/10-bluez-lc3.conf".text = ''
    monitor.bluez.properties = {
      bluez5.enable-lc3 = true
      # bluez5.enable-hw-volume = false
    }
  '';

  # Sensors/monitoring
  environment.systemPackages = with pkgs; [ lm_sensors ];

  # Sleep: GA402RK uses s2idle; don’t force “deep”
  systemd.sleep.extraConfig = ''
    SuspendState=mem
    SuspendMode=
  '';

  system.stateVersion = "25.05";
}
