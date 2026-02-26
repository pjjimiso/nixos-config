{ pkgs, lib, inputs, corporate ? false, ... }:

{
  home.username = "pjjimiso";
  home.homeDirectory = "/home/pjjimiso";
  home.stateVersion = "25.05";

  # Clone oh-my-tmux if not already present
  home.activation.cloneOhMyTmux = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -f "$HOME/.config/tmux/tmux.conf" ]; then
      $DRY_RUN_CMD mkdir -p $HOME/.config/tmux
      $DRY_RUN_CMD ${pkgs.git}/bin/git clone https://github.com/gpakosz/.tmux.git /tmp/oh-my-tmux
      $DRY_RUN_CMD cp /tmp/oh-my-tmux/.tmux.conf $HOME/.config/tmux/tmux.conf
      $DRY_RUN_CMD rm -rf /tmp/oh-my-tmux
    fi
  '';

  home.file.".config/tmux/tmux.conf.local".source = ./tmux/tmux.conf.local;

  # Clone Neovim config if not already present
  home.activation.cloneNvimConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -d "$HOME/.config/nvim" ]; then
      ${pkgs.git}/bin/git clone https://github.com/pjjimiso/kickstart.nvim $HOME/.config/nvim
    fi
  '';

  # Git configuration
  programs.git = {
    enable = true;
    extraConfig = {
      credential.helper = "store";
    };
  };

  # Home-manager packages
  home.packages = with pkgs; [
    tmux
    tmuxinator
    neovim
    bash-completion
    inputs.claude-code.packages.${pkgs.system}.default
  ];

  # Bash aliases
  programs.bash = {
    enable = true;
    enableCompletion = true;
    shellAliases = {
      vim = "nvim";
      mux = "tmuxinator";
      bdshell = "nix shell $HOME/nixos-config#bootdev";
    };
  };

  # Zoxide
  programs.zoxide = {
    enable = true;
    enableBashIntegration = true;
    options = [ "--cmd cd" ];
  };

  # Environment variables
  home.sessionVariables = lib.mkMerge [
    { EDITOR = "nvim"; }
    (lib.mkIf corporate {
      http_proxy = "http://proxy-chain.intel.com:912";
      https_proxy = "http://proxy-chain.intel.com:912";
      no_proxy = "127.0.0.1,localhost,intel.com";
    })
  ];
}
