{ config, lib, pkgs, ... }:

{
  virtualisation.oci-containers.containers = {
    openvas = {
      image = "immauss/openvas:latest";
      ports = [
        "9392:9392" # Web UI
      ];
      volumes = [
        "openvas-data:/data" # Scans and database data
      ];
      environment = {
        PUBLIC_HOSTNAME = "172.16.32.135"; # Web UI accessible host
      };
      extraOptions = [
        "--cap-add=NET_ADMIN" # Required for network scanning
        "--cap-add=NET_RAW"
      ];
    };
  };

  networking.firewall.allowedTCPPorts = [ 9392 ];
}
