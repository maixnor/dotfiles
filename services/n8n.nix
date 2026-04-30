{ config, pkgs, ... }:

{
  services.n8n = {
    enable = true;
    openFirewall = true;
    environment = {
      N8N_SECURE_COOKIE = "false";
      N8N_HOST = "0.0.0.0";
      N8N_PORT = "5678";
    };
  };
}
