{
  description = "NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
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
  };

  outputs = { self, nixpkgs, home-manager, nixos-wsl, nixos-hardware, ... }@inputs:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    in {
      nixosConfigurations.wsl = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          nixos-wsl.nixosModules.wsl
          home-manager.nixosModules.home-manager
          ./hosts/wsl/configuration.nix
        ];
      };

      nixosConfigurations.legion = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          nixos-hardware.nixosModules.lenovo-legion-16iax10h
          home-manager.nixosModules.home-manager
          ./hosts/legion/configuration.nix
        ];
      };

      homeConfigurations = {
        corporate = home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          extraSpecialArgs = { inherit inputs; corporate = true; };
          modules = [ ./home/default.nix ];
        };
        personal = home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          extraSpecialArgs = { inherit inputs; corporate = false; };
          modules = [ ./home/default.nix ];
        };
      };

      packages.x86_64-linux.bootdev = pkgs.callPackage ./pkgs/bootdev.nix { };
    };
}
