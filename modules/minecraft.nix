{ pkgs, config, ... }:

{
  home.packages = with pkgs; [
    prismlauncher
    zulu17
  ];
}
