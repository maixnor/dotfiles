
{ pkgs, config, lib, ... }:

{

  config = {
    services.zerotierone = { 
      enable = true; 
      joinNetworks = [ 
        "8056C2E21CF844AA" 
        "856127940c7eb96b" 
        "856127940c5dae71" 
      ]; 
    };
  };

}
