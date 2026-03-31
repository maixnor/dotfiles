
{ pkgs, config, lib, ... }:

{

  config = {
    services.zerotierone = { 
      enable = true; 
      joinNetworks = [ 
        "856127940c7eb96b" 
        "e3918db483a80e0b"
        "b103a835d2f0706f"
      ]; 
    };
  };

}
