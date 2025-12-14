{ pkgs, ... }:

{
  home.packages = with pkgs; [
    gemini-cli
  ];

  home.file.".gemini/settings.json".text = builtins.toJSON ({
    general = {
      vimMode = true;
      previewFeatures = true;
      disableAutoUpdate = true;
      sessionRetention = {
        enabled = false;
      };
    };
    output = {
      format = "text";
    };
    ui = {
      footer = {
        hideContextPercentage = false;
      };
      hideBanner = true;
      showLineNumbers = false;
      showCitations = true;
      accessibility = {
        disableLoadingPhrases = true;
      };
    };
    security = {
      auth = {
        selectedType = "oauth-personal";
      };
    };
  } // { # Existing settings
    mcpServers = {
      "context7" = {
        command = "${pkgs.nodejs}/bin/npx";
        args = [ "-y" "@upstash/context7-mcp" ];
      };
    };
  });
}
