{ config, lib, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    vim
    gcc
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  virtualisation.docker.enable = true;
}
