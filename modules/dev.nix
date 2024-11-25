{ pkgs, config, ... }:

{
  config = {

    services.languagetool = {
      enable = true;
      port = 6767;
      settings.cacheSize = 5000;
    };

    environment.systemPackages = with pkgs; [
      rustup
      bacon

      gcc

      deno jetbrains.webstorm

      dotnet-sdk_8
      dotnet-runtime_8
      dotnet-aspnetcore_8

      tectonic

      R
      rstudio
<<<<<<< Updated upstream
      vscode
      rPackages.rmarkdown
      rPackages.knitr
=======
>>>>>>> Stashed changes
      pandoc
      # only for Rstudio, normally use tectonic
      texlive.combined.scheme-medium 

      jetbrains.idea-ultimate
      vscodium
      vscode
    ];
  };
}
