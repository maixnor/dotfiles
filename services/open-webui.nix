{ pkgs, ... }:


{
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

  networking.firewall.allowedTCPPorts = [ 7080 ];

  services.nginx.virtualHosts."llm.maixnor.com" = {
    enableACME = true;
    addSSL = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:7080/";
    };
  };
}
