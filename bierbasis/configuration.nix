# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, lib, pkgs, inputs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
			#./nextcloud.nix
			./nvidia.nix
      #./secenv.nix # secenv environment of uni wien
      #./secenv-quick.nix # secenv environment of uni wien
      #../modules/post-vpn.nix
      ../modules/services.nix
    ];

  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.supportedFilesystems = lib.mkForce [ "btrfs" "reiserfs" "vfat" "f2fs" "xfs" "ntfs" "cifs" ];

	boot.kernelPackages = pkgs.linuxPackages_latest;

  hardware.bluetooth.enable = true;

  networking.hostName = "bierbasis";
  networking.networkmanager.enable = true;

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

  services.xserver.enable = true;
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;
  services.xserver.xkb = {
    layout = "us";
    variant = "workman";
  };

  services.printing.enable = true;

  nix.gc = {
    automatic = true;
    persistent = true;
    dates = "weekly";
    options = "--delete-older-than 10d";
  };

  sound.enable = true;
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


  users.users.maixnor = {
    isNormalUser = true;
    description = "Benjamin Meixner";
    extraGroups = [ "networkmanager" "wheel" "libvirtd" ];
    packages = with pkgs; [
      kate
			steam-run
      # thunderbird
      quickemu
      quickgui

      wireguard-tools
      iptables
      nftables
    ];
  };

  networking.nftables.enable = false;
  networking.firewall = { 
    enable = false;
    allowedTCPPortRanges = [ 
      { from = 1714; to = 1764; } # KDE Connect
    ];  
    allowedUDPPortRanges = [ 
      { from = 1714; to = 1764; } # KDE Connect
    ];  
  }; 

  virtualisation.docker.enable = true;
  # virtualisation.libvirtd.enable = true;
	# programs.dconf.enable = true; # virt-manager requires dconf to remember settings
  # needed for uniwien VM
  # virtualisation.virtualbox.host.enable = true;
  # virtualisation.virtualbox.guest.enable = true;
  # users.extraGroups.vboxusers.members = [ "maixnor" ];

  services.ollama = {
    enable = true;
    acceleration = "cuda";
    environmentVariables = {
      HOME = "/tmp/ollama";
    };
  };

  programs.steam = {
    enable = true;
    # disable until needed 
    #remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
    #dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
  };

  environment.systemPackages = with pkgs; [ ];

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1"; # against electron apps flickering on wayland
  };

  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

	programs.nix-ld.enable = true;
	programs.nix-ld.libraries = with pkgs; [
		# place libraries here
	];
  
  services.openssh.enable = true;

  system.autoUpgrade = {
    enable = true;
    persistent = true;
    flake = inputs.self.outPath;
    flags = [
      "--update-input"
      "nixpkgs"
      "-L" # print build logs
    ];
    dates = "02:00";
    randomizedDelaySec = "45min";
  };

  system.stateVersion = "24.05";

}
