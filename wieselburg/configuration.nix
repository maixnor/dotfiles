{ config, pkgs, inputs, ... }:

{
  imports = [ 
    <nixpkgs/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix> 
    ./hardware-configuration.nix
    inputs.nixvim.nixosModules.nixvim

    ../modules/nixvim.nix
  ];

  nixpkgs.config.allowUnfree = true;

  fileSystems."/mnt/mass" = {
    device = "/dev/sda";
    fsType = "ext4";
  };

  networking.useDHCP = false;
  networking.defaultGateway = "10.0.30.1";
  networking.interfaces.ens32.ipv4.addresses = [{
   address = "10.0.30.13";
   prefixLength = 24;
  }];

  users.users.maixnor = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    packages = with pkgs; [ gh ];
  };

  services.openssh.enable = true;  
  services.zerotierone = { enable = true; joinNetworks = ["8056C2E21CF844AA"];};

  services.searx.enable = true;
  services.searx.settings = {
    server.port = 6666;
    server.bind_address = "0.0.0.0";
    server.secret_key = "definetelysecret";
  };

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
