{ config, lib, pkgs, inputs, ... }:

{
  environment.systemPackages = with pkgs; [
    vim
    gcc
    gnumake # avante.nvim's build step downloads prebuilt Rust libs via make
    go
    ripgrep
    fd
    fzf
    xclip
    chromium
    comma
    obsidian
    jq
  ];

  # Loader for generic prebuilt binaries that npm/pip download (e.g. the
  # claude-agent-acp SDK), which are dynamically linked against paths NixOS
  # doesn't have. Without this they hit the stub-ld error.
  programs.nix-ld.enable = true;

  time.timeZone = "America/Phoenix";

  # Allow unfree packages (required for NVIDIA drivers pulled in by nixos-hardware
  # and for Obsidian)
  nixpkgs.config.allowUnfree = true;

  nixpkgs.overlays = [
    (final: prev: {
      # 25.05 ships opencode 0.3.112, which hardcodes github.com in its Copilot auth and
      # so cannot reach the intel-foundry.ghe.com tenant. Track the upstream 2.x release
      # instead, packaged from npm in pkgs/opencode.nix.
      opencode = final.callPackage ../pkgs/opencode.nix { };
    })
  ];

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
