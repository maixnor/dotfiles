{ modulesPath, config, pkgs, inputs, lib, ... }:

{
  imports = [ 
    inputs.disko.nixosModules.default
    (modulesPath + "/installer/scan/not-detected.nix")
    (modulesPath + "/profiles/qemu-guest.nix")
    (import ./disko.nix { device = "/dev/sda"; })
    ./hardware-configuration.nix
    #inputs.nixvim.nixosModules.nixvim
    #../modules/nixvim.nix
  ];

  nixpkgs.config.allowUnfree = true;
  virtualisation.vmware.guest.enable = true;

  ### Bootloader Configuration
  boot.loader.grub = {
    efiSupport = true;
    efiInstallAsRemovable = true;
  };

  ### Networking Configuration
  networking.hostName = "wieselburg";
  # these options do not work with a VM
  networking.defaultGateway = "10.0.30.1";
  networking.nameservers = [ "10.0.30.3" ];
  networking.interfaces.ens32.ipv4.addresses = [{
    address = "10.0.30.200";
    prefixLength = 24;
  }];

  services.openssh.enable = true;

  ### User Configuration
  security.sudo.wheelNeedsPassword = false;
  nix.settings.trusted-users = [ "@wheel" "maixnor" "backup" ];

  users.users.backup = {
    initialPassword = "backup";
    isNormalUser = true;
    extraGroups = [ "wheel" ];
  };

  users.users.maixnor = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDA2UypJYZ7g0TWU1F3PlOkZNwdrFRHPs1pUGmG7kqTTxT0I5NZroQZn1NKKqqFc8H/75bVtja2n0SvpO5PLN2lwaCp60rG1Jz5RCiZ/Fg10VRmawKnx8yOePlOmmchE0ldT5RX84oYKtZbJuLjETMdy/poizyGrBVDQjx8/neI9QEgrbgIZ0WyWu6Cv5Jh2oqZRycVI3ip3oYcEjostLDHmVDW1uaV8qAzIBeL1cGYomW9PxD+pKIelZsPpaBGZrJkjr+1h1FXV1Uh/HQenbMO/qP9ydQzhwpGZ+t6DIy2gwrY2C7WdaJIdWCe6gMk5gPITsYPgS+1Vi58nUGlxOR+VucwYPICIVGYTVFdOr0f9jWrFxtUNuOSyEHExzxlLZJ0EQgRykzNI5rJwMvCBewpnAnaVyHaPM74UKKSXrvjBaYBvJwcwDJDYxn3jkB0YCj0RPsZEBXZzimj7Mh+0oJJ+NGtJ32VtdNDY0bYJoI16sAqIojkYYqEvrOykWwTkfs= maixnor@Bierbasis"
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCxP0stb18D0Cdn0mPORFV8my2/sJErgCU+/3lMhZqJgbMSiOuvyIzjnYNbR/UZgO1zTj9Tnyr6OJbwxRKgv+gGPNWU+hAQU8nWhOUu8B3vIQiC3xp9u/EMkOloUItA2IMui2C/NC9oFLSLFOdOHD6pFu3b/OC59BHs05KKI5DQMF6bJlrGk40PCRa6HdmEk7yFMkhX7v6VSOqCtBPjO96RqsxgrtcfWmhVMFgjchah+0kUNTTOvDXOKSbp2N6Fj6tAG+MQCL1CJ97O+1nBKYRPqZtMNNDbvInkL5xYVmRQIAN6YscENVxzrxFzhtt9zh/S2Kdllus24f/OrYkCxnWtCW8IjVQF/GPXt7VNDRplZIJ6HqFxssLbEt8oEsZfvATys0h7scoEHUVY5sKI+ijxl+HAcPlRokpliEvwV/ffveEo24lmMr3F7iqCrWhDP4M0Ciqjloq7zfpIDEj0mjVR+yX0bcwreB7Hu0Zeso47DrM7HYJpbmucaH2AgZ/3h40= maixnor@bierzelt"
    ];
    packages = with pkgs; [ just gh ];
  };

  ### Services Configuration
  services.zerotierone = { enable = true; joinNetworks = [ "8056C2E21CF844AA" "856127940c7eb96b" ]; };

  services.searx.enable = true;
  services.searx.settings = {
    server.port = 6666;
    server.bind_address = "0.0.0.0";
    server.secret_key = "definetelysecret";
  };

  ### System Packages
  environment.systemPackages = with pkgs; [ 
    git gh just
    wormhole-william
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

  system.stateVersion = "24.11";
}
