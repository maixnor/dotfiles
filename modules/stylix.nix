{ stylix, pkgs, ... }:

{
  stylix.base16Scheme = "${pkgs.base16-schemes}/share/themes/oxocarbon-dark.yaml";
  stylix.targets = {
    gnome.enable = false;
    gtk.enable = false;
    # plymouth.enable = false;
  };
}
