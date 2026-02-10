
{ pkgs, config, ... }:

{

  config = {
    environment.systemPackages = with pkgs; [
      zoxide
      sqlite
      openconnect
      traceroute
      git
      wget xh
      freshfetch
      iftop iotop
      ripgrep
      ripgrep-all
      inotify-tools
      fzf jq
      just ranger
      static-server
      ffmpeg_8-headless
      btop
    ];

    environment.shellAliases = {
      z = "${pkgs.zoxide}/bin/zoxide";
    };
  };

}
