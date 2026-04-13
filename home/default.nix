{ pkgs, lib, config, inputs, corporate ? false, ... }:

{
  home.username = "pjjimiso";
  home.homeDirectory = "/home/pjjimiso";
  home.stateVersion = "25.05";

  # Clone Neovim config if not already present
  home.activation.cloneNvimConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -d "$HOME/.config/nvim" ]; then
      ${pkgs.git}/bin/git clone https://github.com/pjjimiso/kickstart.nvim $HOME/.config/nvim
    fi
  '';

  # sops-nix secrets
  sops.age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
  sops.defaultSopsFile = ../secrets/secrets.yaml;
  sops.secrets.github_pat = {};

  # Authenticate gh CLI after sops-nix has decrypted the PAT
  systemd.user.services.gh-auth = {
    Unit = {
      Description = "Authenticate gh CLI with GitHub PAT";
      After = [ "sops-nix.service" ];
      Requires = [ "sops-nix.service" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "gh-auth" ''
        if ! ${pkgs.gh}/bin/gh auth status &>/dev/null; then
          ${pkgs.gh}/bin/gh auth login --with-token < ${config.sops.secrets.github_pat.path}
        fi
      '';
      RemainAfterExit = true;
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  # Git configuration
  programs.git = {
    enable = true;
    userName  = "Patrick Jimison";
    userEmail = "pat.jimison@gmail.com";
    extraConfig = {
      credential.helper = "store";
      "credential \"https://github.com\"".helper      = [ "" "!gh auth git-credential" ];
      "credential \"https://gist.github.com\"".helper = [ "" "!gh auth git-credential" ];
      http.sslverify = "false";
    };
  };

  # Home-manager packages
  home.packages = with pkgs; [
    tmuxinator
    neovim
    bash-completion
    gh
    btop
    uv
    bitwarden-cli
    bitwarden
    inputs.claude-code.packages.${pkgs.system}.default
    inputs.liftoff.packages.x86_64-linux.default
  ];

  home.file.".local/bin/tmux-kill-session.sh" = {
    source = ./tmux/tmux-kill-session.sh;
    executable = true;
  };

  programs.ghostty = {
    enable = true;
    settings = {
      theme = "tokyonight_night";
    };
  };


  # Tmux
  programs.tmux = {
    enable = true;
    prefix = "C-a";
    terminal = "screen-256color";
    historyLimit = 50000;
    baseIndex = 1;
    mouse = false;
    keyMode = "vi";
    escapeTime = 0;
    disableConfirmationPrompt = true;
    plugins = [
      {
        plugin = inputs.tmux-powerkit.packages.${pkgs.system}.default;
        extraConfig = ''
          set -g @powerkit_status_position "bottom"
          set -g @powerkit_theme "tokyo-night"
          set -g @powerkit_theme_variant "night"
          set -g @powerkit_plugin_datetime_format "%H:%M %m/%d"
          set -g @powerkit_plugins "external(\"\"|\"$(liftoff 2>/dev/null)\"|\"info-base\"|\"info-base-lighter\"|\"300\"),datetime,group(hostname,cpu,memory,battery,uptime)"
        '';
      }
      {
        plugin = pkgs.tmuxPlugins.resurrect;
        extraConfig = ''
          set -g @resurrect-capture-pane-contents 'on'
        '';
      }
      pkgs.tmuxPlugins.yank
      pkgs.tmuxPlugins.vim-tmux-navigator
      {
        plugin = pkgs.tmuxPlugins.t-smart-tmux-session-manager;
        extraConfig = ''
          set -g @t-fzf-find-binding 'ctrl-f:reload(fd -H -d 2 -t d . ~)'
        '';
      }
    ];
    extraConfig = ''
      # Secondary prefix
      set -g prefix2 C-b
      bind C-b send-prefix -2

      # Session management
      bind C-c new-session
      bind C-c command-prompt -p "New session name:" "new-session -s '%%'"
      bind BTab switch-client -l

      # Window/pane creation retaining current path
      bind c new-window -c "#{pane_current_path}"
      bind '"' split-window -v -c "#{pane_current_path}"
      bind '%' split-window -h -c "#{pane_current_path}"
      bind - split-window -v -c "#{pane_current_path}"
      bind _ split-window -h -c "#{pane_current_path}"

      # Pane navigation (vim-style)
      bind -r h select-pane -L
      bind -r j select-pane -D
      bind -r k select-pane -U
      bind -r l select-pane -R

      # Pane resizing
      bind -r H resize-pane -L 2
      bind -r J resize-pane -D 2
      bind -r K resize-pane -U 2
      bind -r L resize-pane -R 2

      # Window navigation
      bind -r C-h previous-window
      bind -r C-l next-window
      bind Tab last-window

      # Window movement (prefix > > and prefix < <)
      bind > switch-client -T move-right
      bind -T move-right > swap-window -d -t +1
      bind < switch-client -T move-left
      bind -T move-left < swap-window -d -t -1

      # Copy mode
      bind Enter copy-mode
      bind -T copy-mode-vi v send -X begin-selection
      bind -T copy-mode-vi C-v send -X rectangle-toggle
      bind -T copy-mode-vi y send -X copy-selection-and-cancel
      bind -T copy-mode-vi Escape send -X cancel
      bind -T copy-mode-vi H send -X start-of-line
      bind -T copy-mode-vi L send -X end-of-line

      # Buffer management
      bind b list-buffers
      bind p paste-buffer -p
      bind P choose-buffer

      # Custom: kill session and switch to next
      bind C-x run-shell "~/.local/bin/tmux-kill-session.sh"

      # Session behavior
      set -g detach-on-destroy off

      # Reload source-file
      bind r source-file ~/.config/tmux/tmux.conf \; display-message "Tmux config reloaded"

      # General settings
      set -sg repeat-time 600
      set -s focus-events on
      setw -g automatic-rename on
      set -g renumber-windows on
      set -g set-titles on
      set -g display-panes-time 800
      set -g display-time 4000
      set -g status-interval 5
      set -g monitor-activity on
      set -g visual-activity off
    '';
  };

  # Bash
  programs.bash = {
    enable = true;
    enableCompletion = true;
    historyControl = [ "ignoredups" ];
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
