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
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  ### Networking Configuration
  networking.hostName = "wieselburg";
  # these options do not work with a VM
  #networking.defaultGateway = "10.0.30.1";
  #networking.interfaces.ens32.ipv4.addresses = [{
  #  address = "10.0.30.13";
  #  prefixLength = 24;
  #}];

  ### User Configuration
  users.users.maixnor = {
    isNormalUser = true;
    initialPassword = "vm-tests-only";
    extraGroups = [ "wheel" ];
    packages = with pkgs; [ just gh ];
  };

  users.users."nixos" = {
    isNormalUser = true;
    initialPassword = "nixos";
    extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
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
      "/etc/machine-id"
      { file = "/var/keys/secret_file"; parentDirectory = { mode = "u=rwx,g=,o="; }; }
    ];
  };

  ### Services Configuration
  services.openssh.enable = true;  
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
