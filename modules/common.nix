{ config, lib, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    vim
    gcc
    go
    ripgrep
    fd
    fzf
    xclip
    chromium
    comma
  ];

  time.timeZone = "America/Phoenix";

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  networking.hosts = {
    "127.0.1.1" = [ "nixos.clients.intel.com" "nixos" ];
  };

  virtualisation.docker.enable = true;
}
