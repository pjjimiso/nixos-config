{ pkgs, lib, corporate ? false, ... }:

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
