{ config, pkgs, ... }:

{
  imports = [ <nixpkgs/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix> ];

  nixpkgs.config.allowUnfree = true;

  networking.useDHCP = false;
  networking.defaultGateway = "10.0.30.1";
  networking.interfaces.ens32.ipv4.addresses = [{
   address = "10.0.30.13";
   prefixLength = 24;
  }];

  users.users.maixnor = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    packages = with pkgs; [ gh neovim ];
  };

  services.openssh.enable = true;  
  services.zerotierone = { enable = true; joinNetworks = ["8056C2E21CF844AA"];};

  # actual services
  environment.systemPackages = with pkgs; [ 
    git 
    wormhole-william
    appflowy
  ];
  # services.jitsi-meet = { enable = true; hostName = "gehinoasch"; };
  # services.mattermost = { enable = true; };
  # services.nextcloud = { enable = true; hostName = "gehinoasch"; };

  # let's encrypt EULA
  security.acme.acceptTerms = true;

}
