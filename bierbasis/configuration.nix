# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ lib, pkgs, inputs, nixvim, ... }:

{
  imports =
    [ 
      #inputs.disko.nixosModules.default
      #(import ./disko.nix { device = "/dev/sdc"; })
      ./hardware-configuration.nix
      ./nvidia.nix
      ./gaming.nix
      ../modules/gh-auth.nix
      ../modules/email.nix
      #../modules/moodle.nix
      #../modules/services.nix
      ../modules/dev.nix
      ../modules/zerotier.nix
      ../services/autoupdate.nix
      ../services/torrent-server.nix
      (import "${inputs.home-manager}/nixos")
    ];

  age.secrets.slack_term = {
    file = ../secrets/slack_term.age;
    mode = "0400";
    owner = "maixnor";
  };

  age.secrets."opencode.json" = {
    file = ../secrets/opencode.json.age;
    owner = "maixnor";
  };

    services.onedrive.enable = true;
  services.autoupdate.enable = true;

  nixpkgs.overlays = [
    (final: prev: {
      xrdb = prev.xorg.xrdb;
    })
  ];
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.auto-optimise-store = true;
  nix.settings.cores = 7; # I have 8 cores and would like 1 to still be reactive during a build

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # faster boot, don't wait on network
  systemd.targets.network-online.wantedBy = pkgs.lib.mkForce []; # Normally ["multi-user.target"]
  systemd.services.NetworkManager-wait-online.enable = false;

  boot.supportedFilesystems = lib.mkForce [ "btrfs" "reiserfs" "vfat" "f2fs" "xfs" "ntfs" "cifs" ];

  boot.kernelPackages = pkgs.linuxPackages_6_12;

  hardware.bluetooth.enable = true;
  hardware.enableRedistributableFirmware = true;

  networking = {
    hostName = "bierbasis";
    networkmanager.enable = true;
    #dhcpcd.extraConfig = "noarp";
    #dhcpcd.wait = "background";
  };

  time.timeZone = "Europe/Vienna";

  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "de_AT.UTF-8";
    LC_IDENTIFICATION = "de_AT.UTF-8";
    LC_MEASUREMENT = "de_AT.UTF-8";
    LC_MONETARY = "de_AT.UTF-8";
    LC_NAME = "de_AT.UTF-8";
    LC_NUMERIC = "de_AT.UTF-8";
    LC_PAPER = "de_AT.UTF-8";
    LC_TELEPHONE = "de_AT.UTF-8";
    LC_TIME = "de_AT.UTF-8";
  };

  services.displayManager.sddm.enable = true;
  services.displayManager.sddm.wayland.enable = true;
  services.desktopManager.plasma6.enable = true;
  services.xserver.enable = false;
  services.xserver.xkb = {
    layout = "us";
    variant = "workman";
  };

  # wu-bachelor-thesis
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql;
    ensureDatabases = [ "postgis" ];
    authentication = pkgs.lib.mkOverride 10 ''
      #type database DBuser origin-address auth-method
      local all       all     trust
      # ipv4
      host  all      all     127.0.0.1/32   trust
      # ipv6
      host all       all     ::1/128        trust
    '';
    extensions = with pkgs.postgresql17Packages; [ postgis ];
  };

  environment.systemPackages = with pkgs; [ 
    kdePackages.qt6ct
    kdePackages.qtstyleplugin-kvantum
    kdePackages.ksshaskpass
    wormhole-william
    gnome-network-displays
    podman-compose # drop in replacement for docker-compose
    #teamviewer # only works with service.teamviewer
    ntfs3g exfat exfatprogs # mounting hdd
    virt-manager
    virt-viewer
    virtiofsd
    spice 
    spice-gtk
    spice-protocol
    virtio-win
    win-spice
    adwaita-icon-theme

    osm2pgsql
    qgis
  ];

  services.printing.enable = true;
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  nix.gc = {
    automatic = true;
    persistent = true;
    dates = "weekly";
    options = "--delete-older-than 10d";
  };

  services.pulseaudio.enable = false;
  security.polkit.enable = true;
  security.rtkit.enable = true;
  security.pam.services.sddm.kwallet.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;
  };

  nix.settings.trusted-users = [ "@wheel" "maixnor" ];

  users.groups.maixnor = {};

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs; };
    users.maixnor = import ./home.nix;
  };

  users.users.maixnor = {
    isNormalUser = true;
    description = "Benjamin Meixner";
    group = "maixnor";
    extraGroups = [ "networkmanager" "wheel" "libvirtd" "docker" "dialout" "uucp" ];
    packages = [
      nixvim
      # pkgs go here
    ];
  };

  networking.nftables.enable = true;
  networking.firewall = { 
    enable = true;
    allowedTCPPortRanges = [ 
      { from = 1714; to = 1764; } # KDE Connect
    ];  
    allowedUDPPortRanges = [ 
      { from = 1714; to = 1764; } # KDE Connect
    ];  
  }; 

  # Virtualization / Containers
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    defaultNetwork.settings.dns_enabled = true;
  };

  programs.dconf.enable = true;
  virtualisation = {
    libvirtd = {
      enable = true;
      qemu = {
        swtpm.enable = true;
      };
    };
    spiceUSBRedirection.enable = true;
  };


  #services.ollama = {
  #  enable = true;
  #  acceleration = "cuda";
  #  environmentVariables = {
  #    HOME = "/var/data/ollama";
  #    FLAKE = "/home/maixnor/repo/dotfiles";
  #  };
  #};

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1"; # against electron apps flickering on wayland
    PODMAN_COMPOSE_WARNING_LOGS = "false";
  };

  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

	programs.nix-ld.enable = true;
	programs.nix-ld.libraries = with pkgs; [
    # place libraries here
	];
  
  services.openssh = {
    enable = true;
    openFirewall = true;
    settings = {
      PasswordAuthentication = true;
      AllowUsers = [ "maixnor" ];
      X11Forwarding = false;
      PermitRootLogin = "no";
    };
  };

  system.stateVersion = "25.11";

}
