{ config, pkgs, modulesPath, nixvim, inputs, ... }:

let 
  hostname = "ottakring";
in
{
  imports = [ 
    ./hardware-configuration.nix
    ../modules/misc-server.nix
    ../modules/gh-auth.nix
    ../services/cloudflared.nix
    ../services/odoo.nix
    ../services/n8n.nix
  ];

  # Bootloader.
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";
  boot.loader.grub.useOSProber = true;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.cores = 2;
  nix.settings.max-jobs = 1;

  nix.gc = {
    automatic = true;
    persistent = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  services.openssh.enable = true;
  services.openssh.settings.PermitRootLogin = "yes";
  services.openssh.authorizedKeysInHomedir = true;

  time.timeZone = "Europe/Vienna";

  networking.networkmanager.enable = true;
  networking.hostName = "${hostname}";

  users.groups.maixnor = {};

  users.users.maixnor = let 
    keys = import ../modules/public-keys.nix;
  in {
    isNormalUser = true;
    group = "maixnor";
    extraGroups = [ "wheel" "web-static" ];
    openssh.authorizedKeys.keys = keys.users.maixnor;
    packages = [ nixvim ];
  };

  users.users.probatio = let 
    keys = import ../modules/public-keys.nix;
  in {
    isNormalUser = true;
    description = "probatio";
    extraGroups = [ "networkmanager" "wheel" "web-static" ];
    openssh.authorizedKeys.keys = keys.users.maixnor;
    packages = [ nixvim ];
  };

  ### System Packages
  environment.systemPackages = with pkgs; [ 
    git just
    wormhole-william
  ];

  ### User Configuration
  security.sudo.wheelNeedsPassword = false;
  nix.settings.trusted-users = [ "@wheel" "probatio" "maixnor" ];

  system.stateVersion = "25.11";
}
