{ pkgs, ... }:

let 
  r-with-my-packages = with pkgs; rWrapper.override{ packages = with rPackages; [ 
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
      lubridate
      tidyverse
      viridisLite
      Benchmarking
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
      r-with-my-packages

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

