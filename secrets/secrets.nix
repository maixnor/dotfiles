let
  keys = import ../modules/public-keys.nix;
  lib = (import <nixpkgs> {}).lib;
  
  maixnor = keys.users.maixnor;
  activeSystems = lib.filter (key: key != "") [
    keys.hosts.wieselburg
    keys.hosts.bierzelt
    keys.hosts.bierbasis
  ];

  all = maixnor ++ activeSystems;
in
{
  # The single source of truth for all Content Factory keys
  "content-factory.env.age".publicKeys = all;
  "github.age".publicKeys = all;
}
