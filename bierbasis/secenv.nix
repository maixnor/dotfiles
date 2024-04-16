
{ config, lib, pkgs, ... }:

{

  networking.firewall = {
    allowedUDPPorts = [ 51980 ]; # Clients and peers can use the same port, see listenport
  };

  networking.wireguard.interfaces = {
    # "wg0" is the network interface name. You can name the interface arbitrarily.
    secenv = {
      # Determines the IP address and subnet of the client's end of the tunnel interface.
      ips = [ "10.80.2.24/15" ];
      listenPort = 51980; # to match firewall allowedUDPPorts (without this wg uses random port numbers)
      privateKey = "6Ca/50w0vkXqygspYi/LyBjfGeM09K4UrCkdAIjvQH4=";

      peers = [
        # For a client configuration, one peer entry for the server will suffice.

        {
          # Public key of the server (not a file path).
          publicKey = "gwcw/BGNjOKch5LzsztHcNqpmW/NIxmDeIIfs7ElGRQ=";
          presharedKey = "A/d0NDt1ZoYlzAUP/5skFsX8VGwNPI9ZY9FrCRHukAs=";

          # Forward all the traffic via VPN.
          allowedIPs = [ "10.80.0.0/15" ];
          # Or forward only particular subnets
          #allowedIPs = [ "10.100.0.1" "91.108.12.0/22" ];

          # Set this to the server IP and port.
          endpoint = "128.131.169.157:51980"; # ToDo: route to endpoint not automatically configured https://wiki.archlinux.org/index.php/WireGuard#Loop_routing https://discourse.nixos.org/t/solved-minimal-firewall-setup-for-wireguard-client/7577

          # Send keepalives every 25 seconds. Important to keep NAT tables alive.
          #persistentKeepalive = 15;
        }
      ];
    };
  };

}
