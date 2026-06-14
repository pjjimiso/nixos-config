{ config, lib, pkgs, inputs, ... }:

{
  imports = [
    ./hardware.nix
    ../../modules/common.nix
  ];

  # Allow unfree packages (required for NVIDIA drivers pulled in by nixos-hardware)
  nixpkgs.config.allowUnfree = true;

  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Networking
  networking.networkmanager.enable = true;

  # Cinnamon desktop environment
  services.xserver.enable = true;
  services.xserver.desktopManager.cinnamon.enable = true;
  services.xserver.displayManager.lightdm.enable = true;

  # Enable OpenGL
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # Load nvidia driver for Xorg and Wayland
  services.xserver.videoDrivers = ["nvidia"];

  hardware.nvidia = {

    # Modesetting is required.
    modesetting.enable = true;

    # Nvidia power management. Experimental, and can cause sleep/suspend to fail.
    powerManagement.enable = false;
    # Fine-grained power management. Turns off GPU when not in use.
    # Experimental and only works on modern Nvidia GPUs (Turing or newer).
    powerManagement.finegrained = false;

    # Use the NVidia open source kernel module (not to be confused with the
    # independent third-party "nouveau" open source driver).
    # Support is limited to the Turing and later architectures. Full list of 
    # supported GPUs is at: 
    # https://github.com/NVIDIA/open-gpu-kernel-modules#compatible-gpus 
    # Only available from driver 515.43.04+
    # Currently alpha-quality/buggy, so false is currently the recommended setting.
    open = true;

    # Enable the Nvidia settings menu,
      # accessible via `nvidia-settings`.
    nvidiaSettings = true;

    # Optionally, you may need to select the appropriate driver version for your specific GPU.
    package = config.boot.kernelPackages.nvidiaPackages.stable;

    # Force PRIME (Hybrid Intel + Nvidia GPU) to use sync instead of offload
    prime = {
      offload.enable = lib.mkForce false;
      offload.enableOffloadCmd = lib.mkForce false;
      sync.enable = true;
    };
  };

  # Audio
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # User account
  users.users.pjjimiso = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "docker" ];
  };

  home-manager.useGlobalPkgs = true;
  home-manager.extraSpecialArgs = { inherit inputs; corporate = false; };
  home-manager.backupFileExtension = ".bak";
  home-manager.users.pjjimiso = {
    imports = [ ../../home/default.nix ];

    # Cinnamon custom shortcuts: open a daily note in a ghostty window (which
    # runs the shared ~/.local/bin/daily-note.sh). These live here, not in the
    # shared home/default.nix, because they are specific to this host's desktop
    # environment. The Windows/WSL equivalents are the AHK hotkeys deployed by
    # hosts/wsl/configuration.nix; both pass the same symbolic day to the same
    # shared script.
    #   Ctrl+.  -> today      Ctrl+,  -> yesterday      Ctrl+/  -> tomorrow
    # `attach` is arg 1 (this host owns its own terminal); the day is arg 2.
    dconf.settings = {
      "org/cinnamon/desktop/keybindings".custom-list = [ "custom0" "custom1" "custom2" ];
      "org/cinnamon/desktop/keybindings/custom-keybindings/custom0" = {
        name = "Daily Note (today)";
        command = "ghostty -e bash -lic 'exec ~/.local/bin/daily-note.sh attach today'";
        binding = [ "<Control>period" ];
      };
      "org/cinnamon/desktop/keybindings/custom-keybindings/custom1" = {
        name = "Daily Note (yesterday)";
        command = "ghostty -e bash -lic 'exec ~/.local/bin/daily-note.sh attach yesterday'";
        binding = [ "<Control>comma" ];
      };
      "org/cinnamon/desktop/keybindings/custom-keybindings/custom2" = {
        name = "Daily Note (tomorrow)";
        command = "ghostty -e bash -lic 'exec ~/.local/bin/daily-note.sh attach tomorrow'";
        binding = [ "<Control>slash" ];
      };
    };
  };

  # This value should match the NixOS release used during installation.
  # Check /etc/nixos/configuration.nix on the laptop if unsure.
  system.stateVersion = "25.05";

  programs.chromium = {
    enable = true;
    homepageLocation = "https://www.google.com";
    extensions = [
      "dbepggeogbaibhgnhhndojpepiihcmeb" # vimium
      "khncfooichmfjbepaaaebmommgaepoid" # unhook
      "nngceckbapebfimnlniiiahkandclblb" # bitwarden
    ];
  };

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = false; # Open ports in the firewall for Steam Remote Play
    dedicatedServer.openFirewall = false; # Open ports in the firewall for Source Dedicated Server
    localNetworkGameTransfers.openFirewall = false; # Open ports in the firewall for Steam Local Network Game Transfers
  };

  services.flatpak.enable = true;

  # Do not suspend/hibernate when closing laptop lid
  services.logind.lidSwitch = "ignore";
}
