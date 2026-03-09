{ pkgs, lib, ... }:

let
  downloadDir = "/var/www/torrents";
in
{
  # Declarative user and group definitions
  users.groups.web-static = {};

  # Ensure the download directory exists with correct permissions
  systemd.tmpfiles.rules = [
    "d ${downloadDir} 0775 transmission web-static -"
    "d ${downloadDir}/.incomplete 0775 transmission web-static -"
  ];

  # Define transmission user and group with fixed IDs for nftables and group access
  users.users.transmission = {
    isSystemUser = true;
    group = "web-static";
    uid = lib.mkDefault 700;
  };
  users.groups.transmission.gid = lib.mkDefault 700;

  # Ensure access for other users
  users.users.maixnor.extraGroups = [ "transmission" "web-static" ];
  users.users.web-static = {
    isSystemUser = true;
    group = "web-static";
    extraGroups = [ "transmission" ];
  };

  services.transmission = {
    enable = true;
    package = pkgs.transmission_4;
    user = "transmission";
    group = "web-static";
    settings = {
      download-dir = downloadDir;
      incomplete-dir-enabled = true;
      incomplete-dir = "${downloadDir}/.incomplete";
      rpc-bind-address = "127.0.0.1";
      rpc-whitelist = "127.0.0.1";
      ratio-limit-enabled = true;
      ratio-limit = 0; # Never seed
      idle-seeding-limit-enabled = true;
      idle-seeding-limit = 0;
      peer-port = 51413;
      # Privacy/Kill-switch related
      utp-enabled = true;
      dht-enabled = false; # Extra safety to prevent leaking
      lpd-enabled = false;
      pex-enabled = false;
    };
  };
}
