{ pkgs, ... }:

let
in
{
  services.openvpn.servers = {
    post.config = '' config /home/maixnor/dotfiles/openvpn/post.conf '';
    wu.config = '' config /home/maixnor/dotfiles/openvpn/post.conf'';
  };
}
