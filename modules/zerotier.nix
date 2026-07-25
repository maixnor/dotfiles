
{ pkgs, config, lib, ... }:

{

  config = {
    services.zerotierone = { 
      enable = true; 
      joinNetworks = [ 
        #"856127940c7eb96b" 
        "0cccb752f76d2546" # BIERLAND
        "e3918db483a80e0b"
        "b103a835d2f0706f"
        "8056c2e21c546100"
        "93afae5963f55ee3" # zert exchange
      ]; 
    };
  };

}
