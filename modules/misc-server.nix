
{ pkgs, config, ... }:

{

  config = {
    environment.systemPackages = with pkgs; [
      opencode
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
    ];

    programs.btop.enable = true;

    environment.shellAliases = {
      z = "{pkgs.zoxide}/bin/zoxide";
    };
  };

}
