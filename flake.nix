{
  description = "Max's NixOS config";

 inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, home-manager, ... }:
  let
    lib = nixpkgs.lib;
    systems = [ "x86_64-linux" ];
    forAllSystems = f: lib.genAttrs systems (system: f system);
    mkHost = { hostname, system ? "x86_64-linux", modules ? [ ] }:
      lib.nixosSystem {
        inherit system;
        modules = modules ++ [
          ./hosts/${hostname}
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.max = import ./home/max.nix;
          }
        ];
      };
  in {
    nixosConfigurations = {
      marvin = mkHost {
        hostname = "marvin";
        modules = [ ];
      };
    };
  };
}
