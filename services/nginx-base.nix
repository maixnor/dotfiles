{ pkgs, ... }:

{
  services.nginx.enable = true;
  services.nginx.recommendedProxySettings = true;
  services.nginx.recommendedTlsSettings = true;

  networking.firewall.allowedTCPPorts = [ 80 443 ]; 

  security.acme = {
    acceptTerms = true;
    defaults.email = "benjamin@meixner.org";
  };
}
