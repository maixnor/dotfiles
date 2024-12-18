# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, lib, inputs, ... }:


{
  imports =
    [
      ./hardware-configuration.nix
      ../modules/services.nix
      ../modules/dev.nix
      ../modules/zerotier.nix
      ../modules/myzaney/config.nix
    ];

  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # faster boot, don't wait on network
  systemd.targets.network-online.wantedBy = pkgs.lib.mkForce []; # Normally ["multi-user.target"]
  systemd.services.NetworkManager-wait-online.enable = false;

  boot.supportedFilesystems = lib.mkForce [ "btrfs" "reiserfs" "vfat" "f2fs" "xfs" "ntfs" "cifs" ];

  hardware.bluetooth.enable = true;
  hardware.enableRedistributableFirmware = true;

  networking.hostName = "bierzelt";
  networking.networkmanager.enable = true;

  #networking.nftables.enable = true;
  networking.firewall = { 
    enable = true;
    allowedTCPPortRanges = [ 
      { from = 1714; to = 1764; } # KDE Connect
    ];  
    allowedUDPPortRanges = [ 
      { from = 1714; to = 1764; } # KDE Connect
    ];  
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

  services.openssh.enable = true;

  services.displayManager.sddm.wayland.enable = true;
  services.desktopManager.plasma6.enable = true;
  services.xserver.videoDrivers = [ "displaylink" "modesetting" ];
  services.xserver.xkb = {
    layout = "us";
    variant = "workman";
  };

  # Battery saving
  services.power-profiles-daemon.enable = false;
  services.thermald.enable = true;
  services.tlp = {
    settings = {
      CPU_BOOST_ON_AC = 1;
      CPU_BOOST_ON_BAT = 0;
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
    };
  };
  powerManagement.cpuFreqGovernor = "schedutil";

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

  hardware.pulseaudio.enable = false;
  security.polkit.enable = true;
	security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  nix.settings.trusted-users = [ "@wheel" "maixnor" ];
  users.users.maixnor = {
    isNormalUser = true;
    description = "Benjamin Meixner";
    extraGroups = [ "networkmanager" "wheel" "libvirtd" "docker" ];
    packages = with pkgs; [ ];
  };

  services.teamviewer.enable = true;

  environment.systemPackages = with pkgs; [ 
    wormhole-william
    teamviewer # only works with service.teamviewer
  ];

  # virtualisation.docker.enable = true;
  # virtualisation.libvirtd.enable = true;

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
