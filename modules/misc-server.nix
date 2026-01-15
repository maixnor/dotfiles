
{ pkgs, config, ... }:

{

  config = {
    environment.systemPackages = with pkgs; [
      zoxide
      sqlite
      openconnect
      traceroute
      gh git
      wget xh
      freshfetch
      btop iftop iotop
      ripgrep
      ripgrep-all
      inotify-tools
      fzf jq
      just ranger
      static-server
      ffmpeg_8-headless
    ];

    environment.shellAliases = {
      z = "{pkgs.zoxide}/bin/zoxide";
    };
  };

}
