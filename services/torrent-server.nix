{ pkgs, lib, ... }:

let
  downloadDir = "/var/www/torrents";
in
{
<<<<<<< HEAD
  # Declarative user and group definitions
  users.groups.web-static = {};

=======
>>>>>>> 36e3969 (chore: remove windscribe vpn completely)
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
<<<<<<< HEAD
=======
    extraGroups = [ "web-static" ];
>>>>>>> 36e3969 (chore: remove windscribe vpn completely)
  };
  users.groups.transmission.gid = lib.mkDefault 700;

  # Ensure access for other users
  users.users.maixnor.extraGroups = [ "transmission" "web-static" ];
<<<<<<< HEAD
=======
  users.groups.web-static = {};
>>>>>>> 36e3969 (chore: remove windscribe vpn completely)
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
<<<<<<< HEAD

  # Kill Switch via nftables
  # We only allow Transmission to communicate over the VPN interface (tun0 or similar)
  # or to the local network for RPC
  networking.nftables.enable = true;
  networking.nftables.ruleset = ''
    table inet filter {
      chain output {
        type filter hook output priority 0; policy accept;

        # Mark traffic from transmission user (UID 700)
        skuid 700 mark set 0x1
      }
    }

    table inet vpn_killswitch {
      chain output {
        type filter hook output priority 1; policy accept;
        
        # Traffic marked 0x1 (from transmission) MUST go through tun0 or lo
        # Using a set to avoid errors if tun0 doesn't exist yet
        meta mark 0x1 oifname != { "tun0", "lo" } drop
      }
    }
  '';
}
=======
}
>>>>>>> 36e3969 (chore: remove windscribe vpn completely)
