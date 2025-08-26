# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, lib, inputs, nixvim, ... }:


{
  imports =
    [
      ./hardware-configuration.nix
      ../modules/dev.nix
      ../modules/zerotier.nix
      (import "${inputs.home-manager}/nixos")
    ];

  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.auto-optimise-store = true;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # faster boot, don't wait on network
  systemd.targets.network-online.wantedBy = pkgs.lib.mkForce []; # Normally ["multi-user.target"]
  systemd.services.NetworkManager-wait-online.enable = false;

  boot.supportedFilesystems = lib.mkForce [ "btrfs" "reiserfs" "vfat" "f2fs" "xfs" "ntfs" "cifs" ];
  boot.kernelPackages = pkgs.linuxPackages_zen;

  hardware.bluetooth.enable = true;
  hardware.enableRedistributableFirmware = true;

  networking.hostName = "bierzelt";
  networking.networkmanager.enable = true;

  #networking.nftables.enable = true;
  networking.firewall = { 
    enable = true;
    allowedTCPPorts = [ 8080 ];
    allowedTCPPortRanges = [ 
      { from = 1714; to = 1764; } # KDE Connect
    ];  
    allowedUDPPortRanges = [ 
      { from = 1714; to = 1764; } # KDE Connect
    ];  
  }; 

  time.timeZone = "America/Lima";

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

  services.openssh.enable = true;

  qt = {
    enable = false;
    style = "breeze";
    platformTheme = "kde";
  };

  services.displayManager.sddm.enable = true;
  services.displayManager.sddm.wayland.enable = true;
  services.desktopManager.plasma6.enable = true;
  services.xserver.videoDrivers = [ "displaylink" "modesetting" ];
  services.xserver.xkb = {
    layout = "us";
    variant = "workman";
  };

  # Battery saving
  services.thermald.enable = true;

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
    options = "--delete-older-than 7d";
  };

  services.pulseaudio.enable = false;
  security.polkit.enable = true;
	security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  nix.settings.trusted-users = [ "@wheel" "maixnor" "alf" ];

  home-manager.users.maixnor = import ./home.nix { inherit config pkgs lib inputs ; };
  users.users.maixnor = {
    isNormalUser = true;
    description = "Benjamin Meixner";
    extraGroups = [ "networkmanager" "wheel" "libvirtd" "docker" ];
    packages = [ nixvim ]; # nixvim
  };

  # users.users.alf = {
  #   isNormalUser = true;
  #   description = "Benjamin Meixner";
  #   extraGroups = [ "networkmanager" "wheel" "libvirtd" "docker" ];
  #   packages = [ nixvim ]; # nixvim
  # };
  # home-manager.users.alf = import ./home-alf.nix { inherit config pkgs lib inputs ; };

  environment.systemPackages = with pkgs; [ 
    wormhole-william
    gnome-network-displays
    # qemu and virt-manager to work with libvirt
    qemu
    quickemu
    virt-manager
    podman-compose # drop in replacement for docker-compose
  ];

  # Virtualization / Containers
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    defaultNetwork.settings.dns_enabled = true;
  };
  virtualisation.libvirtd.enable = true;
	programs.dconf.enable = true; # virt-manager requires dconf to remember settings

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1"; # against chrome and electron apps flickering on wayland
  };

  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

	programs.nix-ld.enable = true;
	programs.nix-ld.libraries = with pkgs; [
		# place libraries here
	];
  
  programs.steam = {
    enable = true;
    #remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
    #dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
  };

  system.stateVersion = "24.11";

}
