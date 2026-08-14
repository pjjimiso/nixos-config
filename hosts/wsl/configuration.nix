{ config, lib, pkgs, inputs, ... }:

{
  imports = [ ../../modules/common.nix ];

  wsl.enable = true;
  wsl.defaultUser = "pjjimiso";
  wsl.wslConf.network.generateHosts = false;

  nixpkgs.config.allowUnfree = true;

  users.users.pjjimiso.extraGroups = [ "docker" ];

  # Lingering starts user@1000.service at boot and creates the runtime dir which this
  # config relies on. Without it, sometimes /run/user/1000 doesn't get created at boot 
  # and things writing to XDG_RUNTIME_DIR fail until the user logs in.
  users.users.pjjimiso.linger = true;

  networking.proxy.default = "http://proxy-chain.intel.com:912";
  networking.proxy.noProxy = "127.0.0.1,localhost,intel.com";

  home-manager.extraSpecialArgs = { inherit inputs; corporate = true; };
  home-manager.useGlobalPkgs = true;
  
  home-manager.users.pjjimiso = { lib, pkgs, ... }:
  let 
      worknotesSync = pkgs.writeShellApplication {
        name = "worknotes-sync";
        runtimeInputs = [ pkgs.rsync pkgs.coreutils ];
        text = ''
          src="$HOME/work_notes/"
          dst="/mnt/c/Users/pjjimiso/OneDrive - Intel Corporation/work_notes/"
          mkdir -p "$dst"
          rsync -rlt --delete --modify-window=2 \
            --no-perms --no-owner --no-group \
            --exclude='.git/' --exclude='*.swp' --exclude='*~' \
            --exclude='.DS_Store' --exclude='4913' \
            "$src" "$dst"
        '';
      };
    in { 
      imports = [ ../../home/default.nix ];
      home.sessionPath = [
        "/mnt/c/win32yank/"
      ];

      # Windows-side launcher for the daily note. Deploys the
      # AutoHotkey v1 script into the Windows Startup folder.
      # Hotkeys open a Windows Terminal running wsl.
      #   Ctrl+.  -> today    Ctrl+,  -> yesterday    Ctrl+/  -> tomorrow
      home.activation.installDailyNoteHotkey =
        lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          startup="/mnt/c/Users/pjjimiso/AppData/Roaming/Microsoft/Windows/Start Menu/Programs/Startup"
          if [ -d "$startup" ]; then
            cat > "$startup/daily-note.ahk" <<'AHK'
; Managed by nixos-config (hosts/wsl/configuration.nix) -- do not edit by hand.
; Daily-note hotkeys (open in the EXISTING WSL/tmux session):
;   Ctrl+.  -> today
;   Ctrl+,  -> yesterday
;   Ctrl+/  -> tomorrow
; The note is created from the template if it doesn't exist yet.
^.::OpenDaily("today")
^,::OpenDaily("yesterday")
^/::OpenDaily("tomorrow")
return

OpenDaily(day) {
    ; The WSL distro is a singleton, so this hidden call shares the tmux server
    ; the visible terminal is attached to. "switch" tells the script to redirect
    ; that client to the chosen day's session instead of opening a new terminal.
    Run, wsl.exe -d NixOS -- bash -lc "exec ~/.local/bin/daily-note.sh switch %day%" ,, Hide
    ; Bring the existing terminal forward; if none is open, open one that attaches.
    if WinExist("ahk_exe WindowsTerminal.exe")
        WinActivate
    else
        Run, wt.exe wsl.exe -d NixOS -- bash -lc "exec ~/.local/bin/daily-note.sh attach %day%"
}
AHK
        fi
        '';

      systemd.user.services.worknotes-sync = {
        Unit.Description = "Mirror ~/work_notes to Intel OneDrive";
        Service = { Type = "oneshot"; ExecStart = "${worknotesSync}/bin/worknotes-sync"; };
      };

      systemd.user.timers.worknotes-sync = {
        Unit.Description = "work_notes -> Intel OneDrive every 5 minutes";
        Timer = { OnBootSec = "2min"; OnUnitActiveSec = "5min"; Persistent = true; };
        Install.WantedBy = [ "timers.target" ];
      };

      # Auto-start Obsidian
      # WSL/WSLg: only default.target is reached in the USER instance
      # Also systemd --user has no DISPLAY so we need to set it explicitly
      systemd.user.services.obsidian = {
        Unit.Description = "Obsidian (drives Obsidian Sync for pj_notes)";
        Service = {
          ExecStart = "${pkgs.obsidian}/bin/obsidian";
          Environment = [ "DISPLAY=:0" ];
          Restart = "on-failure";
          RestartSec = 10;
        };
        Install.WantedBy = [ "default.target" ];
      };

  };

  system.stateVersion = "25.05";
}

