
{ pkgs, ... }:

{
  services.nginx.virtualHosts."maixnor.com" = {
    serverAliases = [ "wieselburg.maixnor.com" "wb.maixnor.com" ];
    addSSL = true;
    enableACME = true;
    root = "/var/www/maixnor.com";
  };
}
