{
  description = "Max's NixOS config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, home-manager, ... }:
  let
    system = "x86_64-linux";
    lib = nixpkgs.lib;
  in {
    nixosConfigurations = {
      marvin = lib.nixosSystem {
        inherit system;
        modules = [
          ./hosts/marvin/configuration.nix
          ./hosts/marvin/hardware-configuration.nix
          home-manager.nixosModules.home-manager {
            home-manager.useGlobalPkgs = true;
	        home-manager.useUserPackages = true;
	        home-manager.users.max = import ./home/max.nix;
	      }
        ];
      };
    };
  };
}
