{ pkgs, ... }:
{
  users.users = {
    max = {
      isNormalUser = true;
      initialPassword = "password";
      extraGroups = [
        "networkmanager"
        "wheel"
        "audio"
        "sound"
        "video"
        "docker"
      ];
    };
  };
}