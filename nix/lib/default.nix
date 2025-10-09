{ inputs, ... }:
inputs.nixpkgs.lib.extend (
  _final: prev:
  let
    inherit (builtins) elem filter;
    inherit (prev)
      attrByPath
      attrValues
      filterAttrs
      hasAttrByPath
      mkIf
      optionalAttrs;
  in
  rec {
    # Guard an attrset so it’s included only when the option exists and is true.
    mkIfOptionEnabled = path: options: config: attrs:
      optionalAttrs (hasAttrByPath path options)
        (mkIf (attrByPath path false config) attrs);

    # Filter only normal users (non-system users)
    filterNormalUsers = users:
      map (u: u.name) (attrValues (
        filterAttrs (_: user: user.isNormalUser) users
      ));

    # Filter only sudo users (in "wheel" group)
    filterSudoUsers = users:
      map (u: u.name) (attrValues (
        filterAttrs (_: user: user ? extraGroups && elem "wheel" user.extraGroups) users
      ));

    # List of home-manager users that match provided filter function
    filterUsers = cfg: pred: let
      users =
        if cfg ? home-manager
        then attrValues cfg.home-manager.users
        else [];
    in
      filter pred users;

    # Boolean if any use matches the above filter function
    anyUser = cfg: pred: (filterUsers cfg pred) != [];
  }
)
