{
  description = "NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    claude-code = {
      url = "github:sadjow/claude-code-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    liftoff = {
      url = "github:pjjimiso/liftoff";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    bootdev-src = {
      url = "github:bootdotdev/bootdev";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, home-manager, nixos-wsl, nixos-hardware, sops-nix, liftoff, nix-index-database, ... }@inputs:
  let
    pkgs = nixpkgs.legacyPackages.x86_64-linux;
  in {
    nixosConfigurations.wsl = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        nix-index-database.nixosModules.default
        nixos-wsl.nixosModules.wsl
        home-manager.nixosModules.home-manager
        { home-manager.sharedModules = [ sops-nix.homeManagerModules.sops ]; }
        ./hosts/wsl/configuration.nix
      ];
    };

    nixosConfigurations.legion = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        nix-index-database.nixosModules.default
        nixos-hardware.nixosModules.lenovo-legion-16iax10h
        home-manager.nixosModules.home-manager
        { home-manager.sharedModules = [ sops-nix.homeManagerModules.sops ]; }
        ./hosts/legion/configuration.nix
      ];
    };

    homeConfigurations = {
      corporate = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        extraSpecialArgs = { inherit inputs; corporate = true; };
        modules = [ 
            sops-nix.homeManagerModules.sops ./home/default.nix 
            nix-index-database.homeModules.default 
        ];
      };
      personal = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        extraSpecialArgs = { inherit inputs; corporate = false; };
        modules = [ 
            sops-nix.homeManagerModules.sops ./home/default.nix 
            nix-index-database.homeModules.default 
        ];
      };
    };

    packages.x86_64-linux.bootdev = pkgs.callPackage ./pkgs/bootdev.nix { src = inputs.bootdev-src; };
  };
}
