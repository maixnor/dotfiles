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

      dotnet-sdk_8
      dotnet-runtime_8
      dotnet-aspnetcore_8

      tectonic

      R
      rPackages.rmarkdown
      rPackages.knitr
      rPackages.vioplot
      rPackages.emdbook
      pandoc
      # only for Rstudio, normally use tectonic
      texlive.combined.scheme-medium 
    ];
  };
}
