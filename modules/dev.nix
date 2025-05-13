{ pkgs, ... }:

let 
  r-with-my-packages = with pkgs; rWrapper.override{ packages = with rPackages; [ 
      languageserver
      rmarkdown 
      extraDistr
      margins
      dplyr
      ggplot2
      ggthemes
      psych
      corrplot
      Hmisc
      apaTables
      nFactors
      qgraph
      xts
      plm
      estimatr
      lubridate
      tidyverse
      viridisLite
      Benchmarking
      # maps
      sf
      rnaturalearth
      rnaturalearthdata
    ];
  };
in {
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
      nodePackages.bash-language-server
      yaml-language-server
      pyright
      marksman

      jetbrains-toolbox

      python314

      # rustup 
      # jetbrains.rust-rover
      rustc cargo rustfmt clippy bacon
      rust-analyzer

      gcc

      deno # jetbrains.webstorm

      jetbrains.rider
      dotnet-sdk_9
      dotnet-runtime_9
      dotnet-aspnetcore_9

      # all the R stuff

      R 
      r-with-my-packages

      rstudio
      tectonic
      quarto
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

