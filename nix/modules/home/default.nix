{ lib, ... }:
let
  inherit (lib) attrNames filterAttrs;
  here = ./.;
  entries = builtins.readDir here;

  # Keep only subdirectories
  moduleDirs = attrNames (filterAttrs (_name: type: type == "directory") entries);

  # Import each submodule by path
  featureModules = builtins.map (name: import "${here}/${name}") moduleDirs;
in {
  imports = featureModules;
}
