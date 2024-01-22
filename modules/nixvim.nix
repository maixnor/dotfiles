{ config, lib, pkgs, nixvim, ... }:

{
  programs.nixvim = {
    enable = true;

    colorschemes.gruvbox.enable = true;
    plugins.lightline.enable = true;
  };
}
