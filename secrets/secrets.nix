let
  keys = import ../modules/public-keys.nix;
  lib = (import <nixpkgs> {}).lib;
  
  maixnor = keys.users.maixnor;
  activeSystems = lib.filter (key: key != "") [
    keys.hosts.wieselburg
    keys.hosts.bierzelt
    keys.hosts.bierbasis
    keys.hosts.ottakring
  ];

  all = maixnor ++ activeSystems;
in
{
  # The single source of truth for all Content Factory keys
  "github.age".publicKeys = all;
  "youtube-cookies.txt.age".publicKeys = all;
  "slack_term.age".publicKeys = all;
  "opencode.json.age".publicKeys = all;
  "odoo_db_password.age".publicKeys = all;
  "odoo_master_password.age".publicKeys = all;
}
