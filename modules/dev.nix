{ pkgs, ... }:

{
  config = {

    services.languagetool = {
      enable = true;
      port = 6767;
      settings.cacheSize = 5000;
    };

    environment.systemPackages = with pkgs; [
      # language servers
      lua-language-server
      gopls
      wl-clipboard
      luajitPackages.lua-lsp
      nil
      nixd
      rust-analyzer
      nodePackages.bash-language-server
      yaml-language-server
      pyright
      marksman

      jetbrains-toolbox

      python314

      # rustup 
      # jetbrains.rust-rover
      rustc cargo rustfmt clippy bacon

      gcc

      deno # jetbrains.webstorm

      dotnet-sdk_8 # jetbrains.rider
      dotnet-runtime_8
      dotnet-aspnetcore_8

      tectonic

      # all the R stuff
      R 
      rPackages.rmarkdown 
      rPackages.extraDistr
      rPackages.dplyr
      rPackages.ggplot2
      rPackages.ggthemes
      rPackages.psych
      rPackages.corrplot
      rPackages.Hmisc
      rPackages.apaTables
      rPackages.nFactors
      rPackages.qgraph
      rPackages.xts
      rPackages.lubridate
      rPackages.tidyverse
      rPackages.viridisLite
      rPackages.Benchmarking

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
