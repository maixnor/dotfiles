{ pkgs, config, lib, ... }:

{

  config = {
    #services.onedrive.enable = true;

    services.searx.enable = true;
    services.searx.settings.server = {
      port = 6666;
      bind_address = "0.0.0.0";
      secret_key = "definetelysecret";
    };

    services.open-webui = {
      enable = true;
      #stateDir = "/home/maixnor/.config/open-webui";
      port = 7080;
      environment = {
        ANONYMIZED_TELEMETRY = "False";
        DO_NOT_TRACK = "True";
        SCARF_NO_ANALYTICS = "True";
        WEBUI_AUTH = "False";
      };
    };
  };

}
