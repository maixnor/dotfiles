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
        enabled = true;
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
  });
}
