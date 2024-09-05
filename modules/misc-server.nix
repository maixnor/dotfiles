
{ pkgs, config, ... }:

{

  config = {
    home.packages = with pkgs; [
      openconnect
      traceroute
      gh git
      wget xh
      freshfetch
      btop iftop iotop
      ripgrep-all
      inotify-tools
    ];
  };

}
