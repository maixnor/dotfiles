{ pkgs, config, lib, ... }:

{

  config = {

    ### Services
    services.searx.enable = true;
    services.searx.redisCreateLocally = true;
    services.searx.settings = {
      server.port = 6666;
      server.bind_address = "0.0.0.0";
      server.secret_key = "definetelysecret";
      formats = [ "html" "json" "csv" ];
    };

    services.open-webui = {
      enable = true;
      port = 7080;
      environment = {
        ANONYMIZED_TELEMETRY = "False";
        DO_NOT_TRACK = "True";
        SCARF_NO_ANALYTICS = "True";
        WEBUI_AUTH = "False";
      };
    };

    ### Nginx and Networking
    networking.firewall.allowedTCPPorts = [ 7080 6666 80 443 ];

    services.nginx.enable = true;
    services.nginx.recommendedProxySettings = true;
    services.nginx.recommendedTlsSettings = true;
    services.nginx.virtualHosts."maixnor.com" = {
      serverAliases = [ "wieselburg.maixnor.com" "wb.maixnor.com" ];
      addSSL = true;
      enableACME = true;
      root = "/var/www/maixnor.com";
    };

    services.nginx.virtualHosts."search.maixnor.com" = {
      enableACME = true;
      addSSL = true;
      locations."/" = {
        proxyPass = "http://127.0.0.1:6666/";
      };
    };

    services.nginx.virtualHosts."llm.maixnor.com" = {
      enableACME = true;
      addSSL = true;
      locations."/" = {
        proxyPass = "http://127.0.0.1:7080/";
      };
    };

    security.acme = {
      acceptTerms = true;
      defaults.email = "benjamin@meixner.org";
    };

  };

}
