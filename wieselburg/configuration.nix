{ config, pkgs, inputs, ... }:

{
  imports = [ 
    ./hardware-configuration.nix
    #inputs.nixvim.nixosModules.nixvim
    #../modules/nixvim.nix
  ];

  nixpkgs.config.allowUnfree = true;

  ### Bootloader Configuration
  boot.loader.grub.enable = true;  # Enables GRUB bootloader
  boot.loader.grub.devices = [ "/dev/sda" ];  # Install GRUB to /dev/sda
  boot.loader.grub.useOSProber = true;        # Enables OS prober if multi-booting

  ### FileSystem Configuration
  fileSystems."/mnt/mass" = {
    device = "/dev/sda";
    fsType = "ext4";
  };

  ### Networking Configuration
  networking.hostName = "wieselburg";
  #networking.useDHCP = false;
  #networking.defaultGateway = "10.0.30.1";
  #networking.interfaces.ens32.ipv4.addresses = [{
  #  address = "10.0.30.13";
  #  prefixLength = 24;
  #}];

  ### User Configuration
  users.users.maixnor = {
    isNormalUser = true;
    # initialPassword = "vm-tests-only";
    extraGroups = [ "wheel" ];
    packages = with pkgs; [ gh ];
  };

  ### Services Configuration
  services.openssh.enable = true;  
  services.zerotierone = { enable = true; joinNetworks = ["8056C2E21CF844AA"]; };

  #services.searx.enable = true;
  #services.searx.settings = {
  #  server.port = 6666;
  #  server.bind_address = "0.0.0.0";
  #  server.secret_key = "definetelysecret";
  #};

  ### System Packages
  environment.systemPackages = with pkgs; [ 
    git 
    #wormhole-william
    #appflowy
  ];

  # Uncomment and configure these services if needed
  # services.jitsi-meet = { enable = true; hostName = "gehinoasch"; };
  # services.mattermost = { enable = true; };
  # services.nextcloud = { 
  #   enable = true; 
  #   hostName = "wieselburg"; 
  #   config.adminpassFile = "./admin.pwd";
  #   configureRedis = true;
  # };

  ### Let's Encrypt (ACME) Configuration
  #security.acme.acceptTerms = true;

  system.stateVersion = "24.05";
}
