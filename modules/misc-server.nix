
{ pkgs, config, ... }:

{

  config = {
    environment.systemPackages = with pkgs; [
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
    ];

    environment.shellAliases = {
      z = "{pkgs.zoxide}/bin/zoxide";
    };
  };

}
