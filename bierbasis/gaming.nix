{ pkgs, ... }:

{

  programs.steam.enable = true;
  programs.steam.gamescopeSession.enable = true;
  programs.gamemode.enable = true;

  environment.systemPackages = with pkgs; [
    protonup
    mangohud
    bottles
    lutris
    steam-run

    winetricks
    protontricks
    wine-wayland
    winePackages.fonts
    winePackages.stable

    corefonts
  ];

}
