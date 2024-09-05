
{ pkgs, config, ... }:

{

  config = {
    home.packages = with pkgs; [
      openconnect
      traceroute
      gh
      wget xh
      freshfetch
      btop iftop iotop
      ripgrep-all

      # general development stuff
      vscodium
      inotify-tools
    ];
  };

}
