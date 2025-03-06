{ pkgs, ... }:

{
  config = {

    services.languagetool = {
      enable = true;
      port = 6767;
      settings.cacheSize = 5000;
    };

    environment.systemPackages = with pkgs; [
      jetbrains-toolbox

      # rustup 
      # jetbrains.rust-rover
      rustc cargo rustfmt clippy bacon

      gcc

      deno # jetbrains.webstorm

      dotnet-sdk_8 # jetbrains.rider
      dotnet-runtime_8
      dotnet-aspnetcore_8

      tectonic

      R
      rPackages.rmarkdown
      rPackages.knitr
      rPackages.ggplot2
      rPackages.dplyr
      rstudio
      vscode
      pandoc
      # only for Rstudio, normally use tectonic
      texlive.combined.scheme-medium 

      # jetbrains.idea-ultimate
      vscodium
      vscode
      postman
      static-server
    ];
  };
}
