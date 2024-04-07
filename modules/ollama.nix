{ pkgs, config, ... }:

{
  home.packages = with pkgs; [
    # ollama service registered in configuration.nix
    kdePackages.alpaka
  ];
}
