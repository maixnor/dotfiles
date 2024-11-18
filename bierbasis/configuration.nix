# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ lib, pkgs, inputs, ... }:

{
  imports =
    [ 
      #inputs.disko.nixosModules.default
      #(import ./disko.nix { device = "/dev/sdc"; })
      ./hardware-configuration.nix
      ./nvidia.nix
      ./gaming.nix
      ../modules/services.nix
      ../modules/dev.nix
      ../modules/zerotier.nix
    ];

  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # faster boot, don't wait on network
  #systemd.targets.network-online.wantedBy = pkgs.lib.mkForce []; # Normally ["multi-user.target"]
  #systemd.services.NetworkManager-wait-online.enable = false;

  boot.supportedFilesystems = lib.mkForce [ "btrfs" "reiserfs" "vfat" "f2fs" "xfs" "ntfs" "cifs" ];

  boot.kernelPackages = pkgs.linuxPackages_latest;

  #hardware.bluetooth.enable = true;

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

  #services.teamviewer.enable = true;

  environment.systemPackages = with pkgs; [ 
    wormhole-william
    #teamviewer # only works with service.teamviewer
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

  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;
  };

  nix.settings.trusted-users = [ "@wheel" "maixnor" ];
  users.users.maixnor = {
    isNormalUser = true;
    description = "Benjamin Meixner";
    extraGroups = [ "networkmanager" "wheel" "libvirtd" "docker" ];
    packages = with pkgs; [
      nh
      # pkgs go here
    ];
  };

  networking.nftables.enable = false;
  #networking.firewall = { 
  #  enable = false;
  #  allowedTCPPortRanges = [ 
  #    { from = 1714; to = 1764; } # KDE Connect
  #  ];  
  #  allowedUDPPortRanges = [ 
  #    { from = 1714; to = 1764; } # KDE Connect
  #  ];  
  #}; 

  virtualisation.docker.enable = true;
  virtualisation.docker.enableOnBoot = false; # boot performance
  # virtualisation.libvirtd.enable = true;
	# programs.dconf.enable = true; # virt-manager requires dconf to remember settings

  services.ollama = {
    enable = true;
    acceleration = "cuda";
    environmentVariables = {
      HOME = "/var/data/ollama";
      FLAKE = "/home/maixnor/repo/dotfiles";
    };
  };

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1"; # against electron apps flickering on wayland
  };

  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

	programs.nix-ld.enable = true;
	programs.nix-ld.libraries = with pkgs; [
    stdenv.cc.cc
    zlib
    fuse3
    icu
    nss
    openssl
    curl
    expat
		# place libraries here
    glib
    glibc
    udev
    nspr
    cups
    libdrm
    mesa # libgbm.so.1
    dbus.lib # libdbus-1.so.3
    xorg.libX11
    xorg.libXcomposite
    xorg.libXdamage
    xorg.libXext
    xorg.libXfixes
    xorg.libXrandr
    xorg.libxcb
    at-spi2-atk # libatk.so.1
    libxkbcommon
    pango
    cairo
    alsa-lib # libasound.so.1
	];
  
  services.openssh.enable = true;

  system.stateVersion = "24.11";

}
