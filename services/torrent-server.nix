{ pkgs, lib, inputs, ... }:

let
  downloadDir = "/var/www/torrents";
in
{
  # Ensure the download directory exists with correct permissions
  systemd.tmpfiles.rules = [
    "d ${downloadDir} 0775 transmission web-static -"
  ];

  services.transmission = {
    enable = true;
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

  # Auto-connect Windscribe on boot
  systemd.services.windscribe-autoconnect = {
    description = "Automatically connect to Windscribe on boot";
    after = [ "network-online.target" "windscribe.service" ];
    wants = [ "network-online.target" "windscribe.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${inputs.windscribe.packages.${pkgs.system}.default}/bin/windscribe connect best";
      ExecStop = "${inputs.windscribe.packages.${pkgs.system}.default}/bin/windscribe disconnect";
    };
  };

  # Kill Switch via nftables
  # We only allow Transmission to communicate over the VPN interface (tun0 or similar)
  # or to the local network for RPC
  networking.nftables.enable = true;
  networking.nftables.ruleset = ''
    table inet filter {
      chain output {
        type filter hook output priority 0; policy accept;

        # Mark traffic from transmission user
        skuid transmission mark set 0x1
      }
    }

    table inet vpn_killswitch {
      chain output {
        type filter hook output priority 1; policy accept;
        
        # Traffic marked 0x1 (from transmission) MUST go through tun0 or lo
        meta mark 0x1 oifname != { "tun0", "lo" } drop
      }
    }
  '';
}
