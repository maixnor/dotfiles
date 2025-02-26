{ pkgs }:

{

  config = {

    services.metabase = {
      enable = true;
      ssl.enable = false;
      openFirewall = true;
      listen.ip = "0.0.0.0";
      listen.port = "9080";
    };

    services.postgresql = {
      enable = true;
      ensureDatabases = [ "metabaseappdb" "actual" ];
      ensureUsers = [ "metabase" "service" ];
    };

    service.nginx = {
      enable = true;
      virtualHosts."maixnor.com" = {
        enableACME = false;
        forceSSL = false;
        locations."/metabase" = {
          proxyPass = "http://127.0.0.1:9080";
        };
      }
    }

  };

}
