{
  description = "Max's NixOS config flake";

  inputs = {
    # Nix Packages
    # https://search.nixos.org/packages
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # Home Manager
    # https://mipmip.github.io/home-manager-option-search
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Map folder structure to flake outputs
    # https://github.com/numtide/blueprint
    blueprint = {
      url = "github:numtide/blueprint";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Declarative disk partitioning
    # https://github.com/nix-community/disko
    disko  = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Persist state
    # https://github.com/nix-community/impermanence
    impermanence.url = "github:nix-community/impermanence";

    # Hardware optimizations
    # https://github.com/NixOS/nixos-hardware
    nixos-hardware.url = "github:nixos/nixos-hardware/master";
  };

  outputs = inputs@{ self, nixpkgs, ... }:
    let
      extendedLib = import ./nix/lib {
        inherit inputs;
        flake = self;
      };

      extendedInputs = inputs // {
        nixpkgs = nixpkgs // { lib = extendedLib; };
      };
    in
    let
      result = inputs.blueprint {
        inputs = extendedInputs;
        prefix = "nix/";
        systems = [ "x86_64-linux" ];
        nixpkgs.config.allowUnfree = true;
      };
    in
    result // {
      lib = extendedLib;
    };
}
