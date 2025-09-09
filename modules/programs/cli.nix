{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    curl
    docker-compose
    git
    openssh
    ranger
    vim
    wget
    wally-cli
  ];
}