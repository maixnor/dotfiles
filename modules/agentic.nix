{ config, pkgs, lib, ... }:

{
  home.packages = with pkgs; [
    gemini-cli
    claude-code
    opencode
  ];

  home.file.".config/opencode/opencode.json".source = config.lib.file.mkOutOfStoreSymlink "/run/agenix/opencode.json";

  home.activation.createOpencodeDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD mkdir -p $VERBOSE_ARG "${config.home.homeDirectory}/.config/opencode"
  '';

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
