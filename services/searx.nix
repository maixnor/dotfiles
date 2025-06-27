{ pkgs, ... }:

{
  services.searx.enable = true;
  services.searx.redisCreateLocally = true;
  services.searx.settings = {
    server.port = 6666;
    server.bind_address = "0.0.0.0";
    server.secret_key = "definetelysecret";
    formats = [ "html" "json" "csv" ];
  };

  networking.firewall.allowedTCPPorts = [ 6666 ];

  services.nginx.virtualHosts."search.maixnor.com" = {
    enableACME = true;
    addSSL = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:6666/";
    };
  };
}
