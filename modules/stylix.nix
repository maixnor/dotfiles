{ stylix, pkgs, ... }:

{
  stylix = {
    enable = true;
    image = pkgs.fetchurl {
      url = "https://upload.wikimedia.org/wikipedia/commons/3/36/Golden_Horn_Metro_Bridge_Mars_2013.jpg";
      sha256 = "sha256-pcTdVAjM2cPJrwHdS61wvpH4pJJlTcE5LlDbJHe1Kno=";
    };
    polarity = "dark";
    base16Scheme = "${pkgs.base16-schemes}/share/themes/oxocarbon-dark.yaml";
    fonts = {
      monospace = {
        name = "Iosevka";
        package = pkgs.nerdfonts;
      };
      # sizes = {
      #   desktop = 14;
      #   popups = 14;
      #   terminal = 16;
      # };
    };
    opacity = {
      terminal = 0.8;
      desktop = 0.95;
      popups = 0.8;
    };
    targets.nixvim.transparentBackground.main = true;
    targets.nixvim.transparentBackground.signColumn = true;
    targets.gnome.enable = false;
    targets.gtk.enable = false;
  };
}
