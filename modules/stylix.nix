{ pkgs, ... }:

{
  stylix = {
    enable = true;
    #image = pkgs.fetchurl {
    #  url = "https://upload.wikimedia.org/wikipedia/commons/3/36/Golden_Horn_Metro_Bridge_Mars_2013.jpg";
    #  sha256 = "sha256-pcTdVAjM2cPJrwHdS61wvpH4pJJlTcE5LlDbJHe1Kno=";
    #};
    polarity = "dark";
    #base16Scheme = "${pkgs.base16-schemes}/share/themes/onedark-dark.yaml";
    generated.palette = {
       author = "";
       base00 = "1d1a19";
       base01 = "68393f";
       base02 = "4c6d93";
       base03 = "81a3b8";
       base04 = "d9b187";
       base05 = "d4e5ef";
       base06 = "ffefd0";
       base07 = "fef0cf";
       base08 = "878fa0";
       base09 = "88929a";
       base0A = "aa8b5f";
       base0B = "ac8a6b";
       base0C = "b18875";
       base0D = "7095af";
       base0E = "c97c5a";
       base0F = "bb855e";
       scheme = "Stylix";
       slug = "stylix";
    };
    fonts = {
      monospace = {
        package = pkgs.nerd-fonts.iosevka-term;
        name = "Iosevka";
      };
      sansSerif = {
        package = pkgs.montserrat;
        name = "Montserrat";
      };
      serif = {
        package = pkgs.montserrat;
        name = "Montserrat";
      };
      sizes = {
        applications = 12;
        terminal = 12;
        popups = 12;
      };
    };
    opacity = {
      terminal = 0.8;
      desktop = 0.95;
      popups = 0.8;
    };
    cursor = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Ice";
      size = 24;
    };
    targets = {
      nixvim.transparentBackground.main = true;
      nixvim.transparentBackground.signColumn = true;

      gnome.enable = true;
      gtk.enable = true;
      kde.enable = false;

      # zaney does that instead
      waybar.enable = false;
      rofi.enable = false;
      hyprland.enable = false;
    };
  };
}
