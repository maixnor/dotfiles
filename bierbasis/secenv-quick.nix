
{ config, lib, pkgs, ... }:

{

  networking.firewall = { 
    allowedUDPPorts = [ 51980 ]; # secenv
    allowedTCPPorts = [ 51980 ]; # secenv
  }; 

  networking.wireguard.enable = true;
  networking.wg-quick.interfaces = {
    secenv = {
      address = [ "10.80.2.24/15" ];
      #dns = [ "10.81.0.2" ];
      privateKey = "6Ca/50w0vkXqygspYi/LyBjfGeM09K4UrCkdAIjvQH4=";
      
      peers = [
        {
          publicKey = "gwcw/BGNjOKch5LzsztHcNqpmW/NIxmDeIIfs7ElGRQ=";
          presharedKey = "A/d0NDt1ZoYlzAUP/5skFsX8VGwNPI9ZY9FrCRHukAs=";
          allowedIPs = [ "10.80.0.0/14" ];
          #allowedIPs = [ "0.0.0.0/0" ];
          endpoint = "128.131.169.157:51980";
        }
      ];
    };
  };
}
