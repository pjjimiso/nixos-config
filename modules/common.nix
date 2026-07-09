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
    obsidian
  ];

  time.timeZone = "America/Phoenix";

  # Allow unfree packages (required for NVIDIA drivers pulled in by nixos-hardware
  # and for Obsidian)
  nixpkgs.config.allowUnfree = true;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  networking.hosts = {
    "127.0.1.1" = [ "nixos.clients.intel.com" "nixos" ];
  };

  virtualisation.docker.enable = true;

  security.sudo.extraRules= [
    {  users = [ "pjjimiso" ];
      commands = [
         { command = "ALL" ;
           options= [ "NOPASSWD" ]; # "SETENV" # Adding the following could be a good idea
        }
      ];
    }
  ];
}
