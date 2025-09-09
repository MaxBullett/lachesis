{ config, lib, pkgs, ... }:
{
  imports = [
    ../../modules/system/base.nix
    ../../modules/programs/cli.nix
    ../../modules/services/docker.nix
    ../../modules/hardware/zsa.nix
    ./hardware-configuration.nix
  ];

  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    resumeDevice = "/dev/mapper/cryptroot";
    kernelPackages = pkgs.linuxPackages_latest;
    kernelParams = [
      "resume_offset=1068547" 	       # swap file offset
      "amd_pstate=active"              # EPP/“guided” behavior via firmware
      "pcie_aspm.policy=powersave"     # OK on this platform; helps idle draw
      "log_buf_len=8M"
      "printk.time=1"
      # Optional stability toggles below (uncomment if needed)
      # "nvme_core.default_ps_max_latency_us=5500"  # soften NVMe APST
      # "nvme_core.default_ps_max_latency_us=0"     # disable APST if freezes
      # "usbcore.autosuspend=2"                     # or -1 to debug USB issues
      # "panic=10"                                  # auto-reboot to collect logs
    ];
  };

  # NetworkManager: moderate Wi-Fi powersave; AX210 likes it better than max powersave.
  networking.hostName = "marvin";
  networking.networkmanager.enable = true;
  networking.networkmanager.wifi.powersave = false;

  users.users.max = {
    isNormalUser = true;
    home = "/home/max";
    extraGroups = [ "wheel" "networkmanager" "audio" "video" "docker" ];
  };
  security.sudo.enable = true;

  # Desktop
  services.displayManager.cosmic-greeter.enable = true;
  services.desktopManager.cosmic.enable = true;
  services.desktopManager.cosmic.xwayland.enable = true;

  # Apps
  programs.firefox.enable = true;
  programs.neovim = {
    enable = true;
    defaultEditor = true;
  };

  # Modern Mesa stack
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # Firmware + updates
  services.fwupd.enable = true;

  # ASUS stack
  services.asusd = {
    enable = true;
    enableUserService = true; # user-level GUI / shortcuts
  };
  services.supergfxd.enable = true;
  # Workaround if supergfxctl doesn't see the GPU (sometimes needed)
  systemd.services.supergfxd.path = [ pkgs.pciutils ];

  # Power management
  services.power-profiles-daemon.enable = true;

  # Bluetooth + LE Audio (LC3)
  hardware.bluetooth = {
    enable = true;
    settings = { General = { Experimental = true; }; }; # needed for LE features
  };

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

  # Debugging
  services.journald.extraConfig = ''
    Storage=persistent
    SystemMaxUse=1G
  '';
}
