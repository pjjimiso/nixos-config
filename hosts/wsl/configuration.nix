{ config, lib, pkgs, ... }:

{
  imports = [ ../../modules/common.nix ];

  wsl.enable = true;
  wsl.defaultUser = "pjjimiso";

  networking.proxy.default = "http://proxy-chain.intel.com:912";
  networking.proxy.noProxy = "127.0.0.1,localhost,intel.com";

  system.stateVersion = "25.05";
}
