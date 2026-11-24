{ pkgs, lib, config, inputs, corporate ? false, ... }:

{
  imports = [ ./skills.nix ./opencode.nix ];

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
    # Claude Code status line built by pkgs/ccstatusline.nix
    (pkgs.callPackage ../pkgs/ccstatusline.nix { })
    inputs.liftoff.packages.x86_64-linux.default
    nodejs # needed for github copilot
    unzip # needed for stylua
    lua-language-server # Lua LSP
    stylua # Lua formatter
    pyright # Python LSP
    util-linux # script provides the pseudo-terminal used by bootdev_run
    (pkgs.callPackage ../pkgs/bootdev.nix { src = inputs.bootdev-src; })
  ];

  # Opencode V2
  programs.opencode = {
    enable = true;
    package = pkgs.callPackage ../pkgs/opencode.nix { };
  };

  xdg.configFile."opencode/plugins" = {
    source = ./opencode/plugins;
    recursive = true;
  };

  # Opencode Agents
  xdg.configFile."opencode/agents" = {
    source = ./opencode/agents;
    recursive = true;
  };

  # Elastic agent and MCP servers live in ~/Projects/agents/elastic
  xdg.configFile."opencode/agents/elastic.md" = lib.mkIf corporate {
    source = config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/Projects/agents/elastic/agent.md";
  };

  # Link ~/.claude/CLAUDE.md to ~/.config/opencode/AGENTS.md for Claude Code
  xdg.configFile."opencode/AGENTS.md".source = ./opencode/AGENTS.md;
  home.file.".claude/CLAUDE.md".source =
    config.lib.file.mkOutOfStoreSymlink "${config.xdg.configHome}/opencode/AGENTS.md";

  # npm's default prefix is the read-only nix store, so here's a writable one
  home.sessionPath = [ "${config.home.homeDirectory}/.npm-global/bin" ];

  home.file.".config/tmux/tmux.conf".source = ./tmux/tmux.conf;

  # Agent skills are installed into ~/.agents/skills by ./skills.nix
  # Also symlinks to ~/.claude/skills for Claude Code

  # opencode still writes package.json and node_modules into this directory itself
  home.file.".config/opencode/opencode.jsonc".source =
    (pkgs.formats.json { }).generate "opencode.jsonc" {
      "$schema" = "https://opencode.ai/config.json";
    };

  # ccstatusline's widget layout - the `statusLine` command lives in
  # ~/.claude/settings.json
  home.file.".config/ccstatusline/settings.json".source =
    (pkgs.formats.json { }).generate "ccstatusline-settings.json" {
      # Upstream bumps this when the settings schema changes
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
      # Print the newest github-copilot/claude-<family>-X.Y model (skips variants like -fast).
      # $1 = family (sonnet|opus), $2 = fallback if the lookup comes back empty.
      _latest_claude() {
        local latest
        latest=$(opencode models 2>/dev/null \
          | grep -E "^github-copilot/claude-$1-[0-9]+(\.[0-9]+)*$" \
          | sort -V | tail -n1)
        echo "''${latest:-$2}"
      }

      # ocr <prompt...>: one-shot opencode run on the latest Claude Sonnet.
      ocr() {
        opencode run --model "$(_latest_claude sonnet github-copilot/claude-sonnet-5.5)" "$@"
      }

      # ingest <work|personal>: librarian agent on the latest Claude Opus.
      ingest() {
        if [[ $# -ne 1 ]]; then
          echo "usage: ingest <work|personal>" >&2
          return 1
        fi
        opencode mini --agent librarian \
          -m "$(_latest_claude opus github-copilot/claude-opus-5.5)" \
          --prompt "ingest new files in $1"
      }

      # sst <host>: ssh + attach/create a tmux session on a host NOT managed by this
      # flake (no remote config needed). Prefix C-s and a top status bar are set
      # inline so the remote layer is distinguishable from the local C-a one.
      # Plain `ssh` stays untouched, so scp/rsync/`ssh host cmd` keep working.
      sst() {
        if [[ $# -ne 1 ]]; then
          echo "usage: sst <host>" >&2
          return 1
        fi
        ssh -t "$1" "tmux -L ssh new-session -A -s remote \; set -g prefix C-s \; bind C-s send-prefix \; set -g status-position top"
      }

      # Launch tmux on startup (see guards above). SSH logins (SSH_TTY set) get a
      # separate server on the `ssh` socket; tmux.conf keys off that socket name to
      # use prefix C-s, so nested remote sessions don't collide with local C-a.
      if [[ $- == *i* ]] && [[ -t 1 ]] \
         && [[ -z "''${TMUX:-}" ]] && [[ -z "''${BASH_EXECUTION_STRING:-}" ]] \
         && command -v tmux >/dev/null; then
        if [[ -n "''${SSH_TTY:-}" ]]; then
          exec tmux -L ssh new-session -A -s remote
        else
          exec tmux new-session -A -s main
        fi
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
