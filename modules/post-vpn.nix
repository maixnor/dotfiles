
{ config, lib, pkgs, ... }:

{

# does not work without password and needs to connect to form a successful configuration -> 2FA
# needs more investigating
  networking.openconnect.interfaces = {
    post = {
      user = "SFPYW4A@post.at";
      protocol = "f5";
      gateway = "vpn.post.at";
    };
  };

}

