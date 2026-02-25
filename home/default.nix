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

  home.packages = with pkgs; [
    git
    tmux
    tmuxinator
    neovim
    inputs.claude-code.packages.${pkgs.system}.default
  ];

  programs.bash.enable = true;

  programs.zoxide = {
    enable = true;
    enableBashIntegration = true;
    options = [ "--cmd cd" ];
  };

  # Proxy environment variables for corporate network
  home.sessionVariables = lib.mkIf corporate {
    http_proxy = "http://proxy-chain.intel.com:912";
    https_proxy = "http://proxy-chain.intel.com:912";
    no_proxy = "127.0.0.1,localhost,intel.com";
  };
}
