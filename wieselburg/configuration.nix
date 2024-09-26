{ config, pkgs, inputs, lib, ... }:

{
  imports = [ 
    inputs.disko.nixosModules.default
    inputs.impermanence.nixosModules.impermanence
    ./hardware-configuration.nix
    (import ./disko.nix { device = "/dev/vda"; })
    #inputs.nixvim.nixosModules.nixvim
    #../modules/nixvim.nix
  ];

  nixpkgs.config.allowUnfree = true;

  ### Bootloader Configuration
  boot.loader.grub = {
    efiSupport = true;
    efiInstallAsRemovable = true;
  };

  ### Networking Configuration
  networking.hostName = "wieselburg";
  # these options do not work with a VM
  #networking.defaultGateway = "10.0.30.1";
  #networking.interfaces.ens32.ipv4.addresses = [{
  #  address = "10.0.30.13";
  #  prefixLength = 24;
  #}];

  services.openssh.enable = true;  

  ### User Configuration
  users.users.maixnor = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDA2UypJYZ7g0TWU1F3PlOkZNwdrFRHPs1pUGmG7kqTTxT0I5NZroQZn1NKKqqFc8H/75bVtja2n0SvpO5PLN2lwaCp60rG1Jz5RCiZ/Fg10VRmawKnx8yOePlOmmchE0ldT5RX84oYKtZbJuLjETMdy/poizyGrBVDQjx8/neI9QEgrbgIZ0WyWu6Cv5Jh2oqZRycVI3ip3oYcEjostLDHmVDW1uaV8qAzIBeL1cGYomW9PxD+pKIelZsPpaBGZrJkjr+1h1FXV1Uh/HQenbMO/qP9ydQzhwpGZ+t6DIy2gwrY2C7WdaJIdWCe6gMk5gPITsYPgS+1Vi58nUGlxOR+VucwYPICIVGYTVFdOr0f9jWrFxtUNuOSyEHExzxlLZJ0EQgRykzNI5rJwMvCBewpnAnaVyHaPM74UKKSXrvjBaYBvJwcwDJDYxn3jkB0YCj0RPsZEBXZzimj7Mh+0oJJ+NGtJ32VtdNDY0bYJoI16sAqIojkYYqEvrOykWwTkfs= maixnor@Bierbasis"
    ];
    packages = with pkgs; [ just gh ];
  };

  boot.initrd.postDeviceCommands = lib.mkAfter ''
    mkdir /btrfs_tmp
    mount /dev/root_vg/root /btrfs_tmp
    if [[ -e /btrfs_tmp/root ]]; then
        mkdir -p /btrfs_tmp/old_roots
        timestamp=$(date --date="@$(stat -c %Y /btrfs_tmp/root)" "+%Y-%m-%-d_%H:%M:%S")
        mv /btrfs_tmp/root "/btrfs_tmp/old_roots/$timestamp"
    fi

    delete_subvolume_recursively() {
        IFS=$'\n'
        for i in $(btrfs subvolume list -o "$1" | cut -f 9- -d ' '); do
            delete_subvolume_recursively "/btrfs_tmp/$i"
        done
        btrfs subvolume delete "$1"
    }

    for i in $(find /btrfs_tmp/old_roots/ -maxdepth 1 -mtime +10); do
        delete_subvolume_recursively "$i"
    done

    btrfs subvolume create /btrfs_tmp/root
    umount /btrfs_tmp
  '';

  fileSystems."/persist".neededForBoot = true;
  environment.persistence."/persist/system" = {
    hideMounts = true;
    directories = [
      "/etc/nixos"
      "/etc/dotfiles"
      "/var/log"
      "/var/lib/nixos"
      "/var/lib/systemd/coredump"
    ];
    files = [
      #"/etc/machine-id"
      #{ file = "/var/keys/secret_file"; parentDirectory = { mode = "u=rwx,g=,o="; }; }
    ];
  };

  ### Services Configuration
  services.zerotierone = { enable = true; joinNetworks = ["8056C2E21CF844AA"]; };

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
