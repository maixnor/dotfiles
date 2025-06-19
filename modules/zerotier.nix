
{ pkgs, config, lib, ... }:

{

  config = {
    services.zerotierone = { 
      enable = true; 
      joinNetworks = [ 
        "856127940c7eb96b" 
      ]; 
    };
  };

}
