{ pkgs, config, ... }:

{
  home.packages = with pkgs; [
    prismlauncher
    xorg.libXrender
    zulu17
  ];
}
