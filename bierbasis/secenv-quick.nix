
{ config, lib, pkgs, ... }:

{

  systemd.services."wg-quick-secenv" = {
    requires = [ "network-online.target" ];
    after = [ "network.target" "network-online.target" ];
    wantedBy = lib.mkForce [ ];
    environment.DEVICE = "secenv";
    path = [ pkgs.wireguard-tools pkgs.iptables pkgs.iproute ];
  };

   networking = {
    wg-quick.interfaces = {
      secenv = {
        address = [ "10.80.2.63/15" ];
        dns = [ "10.82.0.2" ];
        listenPort = 51980;
        privateKey = "6Ca/50w0vkXqygspYi/LyBjfGeM09K4UrCkdAIjvQH4=";

        peers = [{
          publicKey = "gwcw/BGNjOKch5LzsztHcNqpmW/NIxmDeIIfs7ElGRQ=";
          presharedKey = "A/d0NDt1ZoYlzAUP/5skFsX8VGwNPI9ZY9FrCRHukAs=";
          allowedIPs = [ "10.80.0.0/15" ];
          endpoint = "128.131.169.157:51980";
          persistentKeepalive = 25;
        }];

        postUp = ''iptables -I OUTPUT ! -o %i -m mark ! --mark $(wg show %i fwmark) -m addrtype ! --dst-type LOCAL -j REJECT && ip6tables -I OUTPUT ! -o %i -m mark ! --mark $(wg show %i fwmark) -m addrtype ! --dst-type LOCAL -j REJECT'';
        preDown = ''iptables -D OUTPUT ! -o %i -m mark ! --mark $(wg show %i fwmark) -m addrtype ! --dst-type LOCAL -j REJECT && ip6tables -D OUTPUT ! -o %i -m mark ! --mark $(wg show %i fwmark) -m addrtype ! --dst-type LOCAL -j REJECT'';

      };
    };
  };

}
