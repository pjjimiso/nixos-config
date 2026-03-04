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

  # Clone Neovim config if not already present
  home.activation.cloneNvimConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -d "$HOME/.config/nvim" ]; then
      ${pkgs.git}/bin/git clone https://github.com/pjjimiso/kickstart.nvim $HOME/.config/nvim
    fi
  '';

  home.file = lib.mkMerge [
    {
      ".config/tmux/tmux.conf.local".source         = ./tmux/tmux.conf.local;
      ".local/bin/tmux-kill-session.sh"             = { source = ./tmux/tmux-kill-session.sh; executable = true; };
      ".local/bin/next_launch.sh"                   = { source = ./tmux/next_launch.sh;       executable = true; };
    }
    (lib.mapAttrs'
      (name: _: lib.nameValuePair ".config/tmuxinator/${name}" { source = ./tmuxinator + "/${name}"; })
      (lib.filterAttrs
        (name: type: type == "regular" && lib.hasSuffix ".yml" name)
        (builtins.readDir ./tmuxinator)))
  ];

  # Git configuration
  programs.git = {
    enable = true;
    userName  = "Patrick Jimison";
    userEmail = "pat.jimison@gmail.com";
    extraConfig = {
      credential.helper = "store";
      "credential \"https://github.com\"".helper      = [ "" "!gh auth git-credential" ];
      "credential \"https://gist.github.com\"".helper = [ "" "!gh auth git-credential" ];
    };
  };

  # Home-manager packages
  home.packages = with pkgs; [
    tmux
    tmuxinator
    neovim
    bash-completion
    gh
    btop
    uv
    bitwarden-cli
    bitwarden
    inputs.claude-code.packages.${pkgs.system}.default
  ];

  # Bash
  programs.bash = {
    enable = true;
    enableCompletion = true;
    shellAliases = {
      vim     = "nvim";
      mux     = "tmuxinator";
      ls      = "ls --color=auto";
      ll      = "ls -lA --color";
      grep    = "grep --color=auto";
      fgrep   = "fgrep --color=auto";
      egrep   = "egrep --color=auto";
      tmux    = "tmux -2";
      python  = "python3";
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
