{ flake, inputs, ... }:
let
  inherit (inputs.nixpkgs) lib;
  inherit (lib) attrByPath elem filterAttrs hasAttrByPath mkIf optionalAttrs;
in {
  # Filter only normal users (non-system users)
  filterNormalUsers = users:
    filterAttrs (_: u: (u.isNormalUser or false)) users;

  # Filter only sudo users (in "wheel" group)
  filterSudoUsers = users:
    filterAttrs (_: u: elem "wheel" (u.extraGroups or [])) users;

  # Guard an attrset so it’s included only when the option exists and is true.
  mkIfOptionEnabled = path: options: config: attrs:
    optionalAttrs (hasAttrByPath path options)
      (mkIf (attrByPath path false config) attrs);
}
