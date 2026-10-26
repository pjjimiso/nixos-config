{ config, lib, pkgs, ... }:

# Compatibility module for Home Manager 25.05, which predates programs.opencode.
# Remove this import when upgrading to a release with the upstream module.
let
  cfg = config.programs.opencode;
in
{
  options.programs.opencode = {
    enable = lib.mkEnableOption "OpenCode";
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.opencode;
      description = "OpenCode package to install.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];
  };
}
