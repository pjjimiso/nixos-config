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
    tmux
    tmuxinator
    neovim
    bash-completion
    gh
    btop
    bat
    uv
    bitwarden-cli
    bitwarden
    inputs.claude-code.packages.${pkgs.system}.default
    # Claude Code status line. Pinned npm release built by pkgs/ccstatusline.nix, so
    # rendering never shells out to the network -- upstream's own installer writes
    # `npx -y ccstatusline@latest` into settings.json, which re-resolves on every repaint.
    (pkgs.callPackage ../pkgs/ccstatusline.nix { })
    inputs.liftoff.packages.x86_64-linux.default
    nodejs # needed for github copilot
    unzip # needed for stylua
    lua-language-server # Lua LSP
    stylua # Lua formatter
    pyright # Python LSP
    opencode
  ];

  # npm's default prefix is the read-only nix store, so `npm install -g` fails without a
  # writable one. See NPM_CONFIG_PREFIX in home.sessionVariables below.
  home.sessionPath = [ "${config.home.homeDirectory}/.npm-global/bin" ];

  home.file.".config/tmux/tmux.conf".source = ./tmux/tmux.conf;

  # The plugin is just this skill directory (plus an opt-in always-on hook we don't
  # use), so symlink it from the pinned input instead. Invoke with /i-have-adhd;
  # "stop adhd mode" turns it off for the session.
  home.file.".claude/skills/i-have-adhd".source =
    "${inputs.i-have-adhd}/skills/i-have-adhd";

  # Same skill for opencode, The plugin only imports node builtins, so it runs from the
  # read-only store fine. opencode still writes package.json and node_modules into
  # this directory itself; only opencode.jsonc is managed here.
  home.file.".config/opencode/opencode.jsonc".source =
    (pkgs.formats.json { }).generate "opencode.jsonc" {
      "$schema" = "https://opencode.ai/config.json";
      plugin = [ "${inputs.i-have-adhd}/.opencode/plugins/i-have-adhd.mjs" ];
    };

  # ccstatusline's widget layout, so every machine renders the same status line. This
  # lands as a read-only store symlink, so the `ccstatusline` TUI can preview changes
  # but not save them -- edit this attrset and rebuild instead. The TUI's "install to
  # Claude Code" step is likewise not used; the `statusLine` command lives in
  # ~/.claude/settings.json, which the separate claude-config repo owns.
  home.file.".config/ccstatusline/settings.json".source =
    (pkgs.formats.json { }).generate "ccstatusline-settings.json" {
      # Upstream bumps this when the settings schema changes. On a mismatch ccstatusline
      # migrates and rewrites the file, which it cannot do here -- so on a version bump,
      # check upstream and update this alongside the package.
      version = 4;
      lines = [
        [
          { id = "1"; type = "model"; color = "cyan"; }
          { id = "2"; type = "separator"; }
          # git-changes below still say "no git" there -- add the same hide if that bugs you.
          { id = "3"; type = "git-root-dir"; color = "ansi256:117"; metadata.hide = "no-git"; }   # light blue   #87d7ff
          { id = "4"; type = "separator"; }
          { id = "5"; type = "git-branch"; color = "ansi256:120"; }   # light green  #87ff87
          { id = "6"; type = "separator"; }
          { id = "7"; type = "git-changes"; color = "ansi256:230"; }   # cream        #ffffd7
          { id = "8"; type = "separator"; }
          # "Context: [##--------------] 100k/1.0M (10%)"
          { id = "9"; type = "context-bar"; color = "yellow"; metadata.display = "progress-short"; }
          #{ id = "10"; type = "context-percentage"; color = "yellow"; bold = true; rawValue = true; }
        ]
        [ ]
        [ ]
      ];
      flexMode = "full";
      compactThreshold = 60;
      colorLevel = 2;
      defaultPaddingSide = "both";
      inheritSeparatorColors = false;
      globalBold = false;
      gitCacheTtlSeconds = 5;
      terminalWidthCacheTtlSeconds = 5;
      customCommandCacheTtlSeconds = 0;
      minimalistMode = false;
      powerline = {
        enabled = false;
        separators = [ "" ];
        separatorInvertBackground = [ false ];
        startCaps = [ ];
        endCaps = [ ];
        autoAlign = false;
        continueThemeAcrossLines = false;
      };
    };

  home.activation.installTpm = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
      ${pkgs.git}/bin/git clone https://github.com/tmux-plugins/tpm \
        "$HOME/.tmux/plugins/tpm"
    fi
    "$HOME/.tmux/plugins/tpm/bin/install_plugins" || true
  '';

  home.file.".local/bin/tmux-kill-session.sh" = {
    source = ./tmux/tmux-kill-session.sh;
    executable = true;
  };

  home.file.".local/bin/tmux-ssh-finder.sh" = {
    source = ./tmux/tmux-ssh-finder.sh;
    executable = true;
  };

  home.file.".local/bin/note-vaults.sh" = {
    source = ./tmux/note-vaults.sh;
    executable = false;
  };

  home.file.".local/bin/tmux-note-finder.sh" = {
    source = ./tmux/tmux-note-finder.sh;
    executable = true;
  };

  home.file.".local/bin/tmux-note-name-finder.sh" = {
    source = ./tmux/tmux-note-name-finder.sh;
    executable = true;
  };

  home.file.".local/bin/daily-note.sh" = {
    source = ./tmux/daily-note.sh;
    executable = true;
  };

  home.file.".local/bin/tmux-daily-finder.sh" = {
    source = ./tmux/tmux-daily-finder.sh;
    executable = true;
  };

  programs.ghostty = {
    enable = true;
    settings = {
      theme = "tokyonight_night";
      keybind = "shift+insert=paste_from_clipboard";
    };
  };

  # Bash
  programs.bash = {
    enable = true;
    enableCompletion = true;
    historyControl = [ "ignoredups" ];

    # Launch tmux on startup
    # Guards:
    #   $- == *i*                 -> interactive shells only.
    #   -t 1                      -> real terminal (skip pipes/scp/etc.).
    #   -z $TMUX                  -> don't nest inside an existing tmux
    #   -z BASH_EXECUTION_STRING  -> skip `bash -lc/-lic '<cmd>'` (i.e. daily-note.sh)
    initExtra = ''
      if [[ $- == *i* ]] && [[ -t 1 ]] \
         && [[ -z "''${TMUX:-}" ]] && [[ -z "''${BASH_EXECUTION_STRING:-}" ]] \
         && command -v tmux >/dev/null; then
        exec tmux new-session -A -s main
      fi
    '';

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
      ansible_2_8 = "nix-shell -p ansible -I nixpkgs=https://github.com/NixOS/nixpkgs/archive/nixos-19.09.tar.gz";
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
    {
      EDITOR = "nvim";
      # npm's default prefix is the read-only nix store, so `npm install -g` fails.
      # Currently needed for claude-agent-acp, the ACP adapter avante.nvim spawns to
      # drive Claude Code.
      NPM_CONFIG_PREFIX = "${config.home.homeDirectory}/.npm-global";
    }
    (lib.mkIf corporate {
      http_proxy = "http://proxy-chain.intel.com:912";
      https_proxy = "http://proxy-chain.intel.com:912";
      no_proxy = "127.0.0.1,localhost,intel.com";
    })
  ];
}
