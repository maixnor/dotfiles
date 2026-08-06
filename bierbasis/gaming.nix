{ pkgs, ... }:

{

  programs.steam = {
    enable = true;
    gamescopeSession.enable = true;
    remotePlay.openFirewall = true;
  };
  hardware.steam-hardware.enable = true;
  programs.gamemode.enable = true;

  environment.systemPackages = with pkgs; [
    #protonup-rs
    mangohud
    bottles
    lutris
    steam-run

    winetricks
    protontricks
    wine-wayland
    winePackages.fonts
    winePackages.stable

  ];

}
