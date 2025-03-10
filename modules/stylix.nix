{ pkgs, ... }:

{
  stylix = {
    enable = true;
    polarity = "dark";
    base16Scheme = "${pkgs.base16-schemes}/share/themes/onedark-dark.yaml";
    fonts = {
      monospace = {
        package = pkgs.nerd-fonts.fira-code;
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

      gnome.enable = false;
      gtk.enable = false;
      kde.enable = false;

      # zaney does that instead
      waybar.enable = false;
      rofi.enable = false;
      hyprland.enable = false;
    };
  };
}
