{ modulesPath, config, pkgs, inputs, lib, ... }:

{
  imports = [ 
    (modulesPath + "/installer/scan/not-detected.nix")
    (modulesPath + "/profiles/qemu-guest.nix")
    ./vpsadminos.nix # for vpsfree.cz
    ./languagebuddy-deps.nix
    inputs.nixvim.nixosModules.nixvim
    ../modules/nixvim.nix
    ../modules/zerotier.nix
    ../modules/services.nix    
  ];

  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  virtualisation.vmware.guest.enable = true;

  systemd.services.nix-build = {
    serviceConfig = {
      MemoryLimit = "2G";
    };
  };
  nix.settings.cores = 4;

  services.openssh.enable = true;
  services.openssh.settings.PermitRootLogin = "yes";
  services.openssh.authorizedKeysInHomedir = true;

  time.timeZone = "Europe/Amsterdam";

  users.users.maixnor = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDA2UypJYZ7g0TWU1F3PlOkZNwdrFRHPs1pUGmG7kqTTxT0I5NZroQZn1NKKqqFc8H/75bVtja2n0SvpO5PLN2lwaCp60rG1Jz5RCiZ/Fg10VRmawKnx8yOePlOmmchE0ldT5RX84oYKtZbJuLjETMdy/poizyGrBVDQjx8/neI9QEgrbgIZ0WyWu6Cv5Jh2oqZRycVI3ip3oYcEjostLDHmVDW1uaV8qAzIBeL1cGYomW9PxD+pKIelZsPpaBGZrJkjr+1h1FXV1Uh/HQenbMO/qP9ydQzhwpGZ+t6DIy2gwrY2C7WdaJIdWCe6gMk5gPITsYPgS+1Vi58nUGlxOR+VucwYPICIVGYTVFdOr0f9jWrFxtUNuOSyEHExzxlLZJ0EQgRykzNI5rJwMvCBewpnAnaVyHaPM74UKKSXrvjBaYBvJwcwDJDYxn3jkB0YCj0RPsZEBXZzimj7Mh+0oJJ+NGtJ32VtdNDY0bYJoI16sAqIojkYYqEvrOykWwTkfs= maixnor@Bierbasis"
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCxP0stb18D0Cdn0mPORFV8my2/sJErgCU+/3lMhZqJgbMSiOuvyIzjnYNbR/UZgO1zTj9Tnyr6OJbwxRKgv+gGPNWU+hAQU8nWhOUu8B3vIQiC3xp9u/EMkOloUItA2IMui2C/NC9oFLSLFOdOHD6pFu3b/OC59BHs05KKI5DQMF6bJlrGk40PCRa6HdmEk7yFMkhX7v6VSOqCtBPjO96RqsxgrtcfWmhVMFgjchah+0kUNTTOvDXOKSbp2N6Fj6tAG+MQCL1CJ97O+1nBKYRPqZtMNNDbvInkL5xYVmRQIAN6YscENVxzrxFzhtt9zh/S2Kdllus24f/OrYkCxnWtCW8IjVQF/GPXt7VNDRplZIJ6HqFxssLbEt8oEsZfvATys0h7scoEHUVY5sKI+ijxl+HAcPlRokpliEvwV/ffveEo24lmMr3F7iqCrWhDP4M0Ciqjloq7zfpIDEj0mjVR+yX0bcwreB7Hu0Zeso47DrM7HYJpbmucaH2AgZ/3h40= maixnor@bierzelt"
    ];
    packages = with pkgs; [ just gh ];
  };

  networking.hostName = "wieselburg";

  ### System Packages
  environment.systemPackages = with pkgs; [ 
    git gh just
    wormhole-william
    #appflowy
  ];

  ### User Configuration
  security.sudo.wheelNeedsPassword = false;
  nix.settings.trusted-users = [ "@wheel" "maixnor" "backup" ];
  # Uncomment and configure these services if needed
  # services.jitsi-meet = { enable = true; hostName = "gehinoasch"; };
  # services.mattermost = { enable = true; };
  # services.nextcloud = { 
  #   enable = true; 
  #   hostName = "wieselburg"; 
  #   config.adminpassFile = "./admin.pwd";
  #   configureRedis = true;
  # };

  system.stateVersion = "24.11";
}
