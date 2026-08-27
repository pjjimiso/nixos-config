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
      # so cannot reach the intel-foundry.ghe.com tenant. Enterprise support (the
      # "GitHub Enterprise" deployment-type prompt) landed in 1.x, so track unstable.
      #
      # Unstable's opencode segfaults inside ld.so on launch. The ELF is malformed: the
      # ELF gABI requires PT_LOAD entries to appear sorted on ascending p_vaddr, but
      # nixpkgs' bun is patchelf'd (adding a LOAD to hold the long nix interpreter
      # path), and `bun build --compile` then PREPENDS the payload segment -- which has
      # the highest vaddr -- to the header table. glibc <=2.40 tolerated the disorder;
      # 2.42 does not, and the .bss tail of the last-listed segment ends up unmapped.
      #
      # Re-running patchelf with the interpreter it already has is a semantic no-op that
      # forces the program header table to be rewritten in sorted order, repairing the
      # layout while keeping the glibc the binary was built against.
      #
      # bin/opencode is a compiled makeBinaryWrapper with the original store path baked
      # in, so it must be regenerated against the repaired binary; a plain copy would
      # still exec the malformed one.
      opencode =
        let
          upstream = inputs.nixpkgs-unstable.legacyPackages.${prev.system}.opencode;
        in
        prev.runCommandLocal "opencode-${upstream.version}"
          {
            nativeBuildInputs = [ prev.patchelf prev.makeBinaryWrapper ];
            inherit (upstream) meta;
            passthru = { inherit (upstream) version; };
          }
          ''
            mkdir -p $out/bin
            cp -r ${upstream}/share $out/share

            cp ${upstream}/bin/.opencode-wrapped $out/bin/.opencode-real
            chmod u+w $out/bin/.opencode-real
            patchelf --set-interpreter \
              "$(patchelf --print-interpreter $out/bin/.opencode-real)" \
              $out/bin/.opencode-real

            makeBinaryWrapper $out/bin/.opencode-real $out/bin/opencode \
              --prefix PATH : ${prev.lib.makeBinPath [ prev.ripgrep ]} \
              --set OPENCODE_DISABLE_AUTOUPDATE true
          '';
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
