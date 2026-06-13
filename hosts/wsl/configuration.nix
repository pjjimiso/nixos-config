{ config, lib, pkgs, inputs, ... }:

{
  imports = [ ../../modules/common.nix ];

  wsl.enable = true;
  wsl.defaultUser = "pjjimiso";
  wsl.wslConf.network.generateHosts = false;

  users.users.pjjimiso.extraGroups = [ "docker" ];

  networking.proxy.default = "http://proxy-chain.intel.com:912";
  networking.proxy.noProxy = "127.0.0.1,localhost,intel.com";

  home-manager.extraSpecialArgs = { inherit inputs; corporate = true; };
  home-manager.users.pjjimiso = { lib, ... }: {
    imports = [ ../../home/default.nix ];
    home.sessionPath = [
      "/mnt/c/win32yank/"
    ];

    # Windows-side launcher for the daily note. NixOS can't own the global
    # hotkey (it lives above the WSL boundary), but it can deploy the
    # AutoHotkey v1 script into the Windows Startup folder via the /mnt/c
    # mount. Ctrl+Alt+D opens a Windows Terminal running wsl -> the shared
    # ~/.local/bin/daily-note.sh. Prereq: AutoHotkey installed on Windows.
    home.activation.installDailyNoteHotkey =
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        startup="/mnt/c/Users/pjjimiso/AppData/Roaming/Microsoft/Windows/Start Menu/Programs/Startup"
        if [ -d "$startup" ]; then
          cat > "$startup/daily-note.ahk" <<'AHK'
; Managed by nixos-config (hosts/wsl/configuration.nix) -- do not edit by hand.
; Ctrl+.: open today's pj_notes daily note in the EXISTING WSL/tmux session.
^.::
; The WSL distro is a singleton, so this hidden call shares the tmux server the
; visible terminal is attached to. "switch" tells the script to redirect that
; client to today's session instead of trying to open a new terminal.
Run, wsl.exe -d NixOS -- bash -lc "exec ~/.local/bin/daily-note.sh switch" ,, Hide
; Bring the existing terminal forward; if none is open, open one that attaches.
if WinExist("ahk_exe WindowsTerminal.exe")
    WinActivate
else
    Run, wt.exe wsl.exe -d NixOS -- bash -lc "exec ~/.local/bin/daily-note.sh"
return
AHK
        fi
      '';
  };

  system.stateVersion = "25.05";
}
