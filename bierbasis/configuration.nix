# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
			#./nextcloud.nix
			./nvidia.nix
      #./secenv.nix # secenv environment of uni wien
      ./secenv-quick.nix # secenv environment of uni wien
      #../modules/post-vpn.nix
    ];

  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

	boot.kernelPackages = pkgs.linuxPackages_latest;

  hardware.bluetooth.enable = true;

  networking.hostName = "Bierbasis";
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

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Enable the KDE Plasma Desktop Environment.
  services.xserver.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "workman";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  nix.gc = {
    automatic = true;
    persistent = true;
    dates = "weekly";
    options = "--delete-older-than 10d";
  };

  # Enable sound with pipewire.
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

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.maixnor = {
    isNormalUser = true;
    description = "Benjamin Meixner";
    extraGroups = [ "networkmanager" "wheel" "libvirtd" ];
    packages = with pkgs; [
      firefox
      kate
			virt-manager
			steam-run
      # thunderbird
      quickemu
      quickgui

      wireguard-tools
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
    # allowedUDPPorts = [ 51980 ]; # secenv
  }; 

  # Enable WireGuard
  # networking.wg-quick.interfaces = {
  #   secenv = {
  #     address = [ "10.80.2.24/15" ];
  #     # dns = [ "10.81.0.2" ];
  #     privateKey = "6Ca/50w0vkXqygspYi/LyBjfGeM09K4UrCkdAIjvQH4=";
  #     
  #     peers = [
  #       {
  #         publicKey = "gwcw/BGNjOKch5LzsztHcNqpmW/NIxmDeIIfs7ElGRQ=";
  #         presharedKey = "A/d0NDt1ZoYlzAUP/5skFsX8VGwNPI9ZY9FrCRHukAs=";
  #         allowedIPs = [ "10.80.0.0/15" ];
  #         endpoint = "128.131.169.157:51980";
  #         persistentKeepalive = 15;
  #       }
  #     ];
  #   };
  # };

  # virtualisation.docker.enable = true;
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
    remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
    dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
  };

  environment.systemPackages = with pkgs; [
    #  vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    #  wget
  ];

  environment.sessionVariables = rec {
    ELECTRON_OZONE_PLATFORM_HINT = "auto"; # against electron apps flickering on wayland
  };

  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  # services.openssh.enable = true;

  system.stateVersion = "24.05";

}
