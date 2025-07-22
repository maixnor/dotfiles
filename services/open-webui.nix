{ pkgs, ... }:

{
  # Import the modern AI research stack instead of basic open-webui
  imports = [ ./ai-research.nix ];

  # Keep the old open-webui disabled for now (you can remove this section later)
  # services.open-webui = {
  #   enable = false;
  #   port = 7080;
  #   environment = {
  #     ANONYMIZED_TELEMETRY = "False";
  #     DO_NOT_TRACK = "True";
  #     SCARF_NO_ANALYTICS = "True";
  #     WEBUI_AUTH = "False";
  #   };
  # };

  # Old firewall rule (now handled in ai-research.nix)
  # networking.firewall.allowedTCPPorts = [ 7080 ];

  # Redirect old domain to new research interface
}
