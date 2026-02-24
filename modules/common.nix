{ config, lib, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    vim
    git
    tmux
    tmuxinator
    neovim
    gcc
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
}
