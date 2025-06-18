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
      #../modules/moodle.nix
      ../modules/services.nix
      ../modules/dev.nix
      ../modules/zerotier.nix
    ];

  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.auto-optimise-store = true;
  nix.settings.cores = 7; # I have 8 cores and would like 1 to still be reactive during a build

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # faster boot, don't wait on network
  #systemd.targets.network-online.wantedBy = pkgs.lib.mkForce []; # Normally ["multi-user.target"]
  #systemd.services.NetworkManager-wait-online.enable = false;

  boot.supportedFilesystems = lib.mkForce [ "btrfs" ];

  boot.kernelPackages = pkgs.linuxPackages_zen;

  hardware.bluetooth.enable = true;

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

  qt = {
    enable = true;
    platformTheme = "kde";
    style = "breeze";
  };

  #services.teamviewer.enable = true;

  environment.systemPackages = with pkgs; [ 
    wormhole-william
    podman-compose # drop in replacement for docker-compose
    #teamviewer # only works with service.teamviewer
    ntfs3g exfat exfatprogs # mounting hdd
    virt-manager
    virt-viewer
    virtiofsd
    spice 
    spice-gtk
    spice-protocol
    win-virtio
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
  networking.firewall = { 
    enable = false;
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
        ovmf.enable = true;
        ovmf.packages = [ pkgs.OVMFFull.fd ];
      };
    };
    spiceUSBRedirection.enable = true;
  };


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
    PODMAN_COMPOSE_WARNING_LOGS = "false";
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

    # jetbrains tools
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    bzip2
    cairo
    cups
    curlWithGnuTls
    dbus
    dbus-glib
    desktop-file-utils
    e2fsprogs
    expat
    flac
    fontconfig
    freeglut
    freetype
    fribidi
    fuse
    fuse3
    gdk-pixbuf
    glew110
    glib
    gmp
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-ugly
    gst_all_1.gstreamer
    gtk2
    harfbuzz
    icu
    keyutils.lib
    libGL
    libGLU
    libappindicator-gtk2
    libcaca
    libcanberra
    libcap
    libclang.lib
    libdbusmenu
    libdrm
    libgcrypt
    libgpg-error
    libidn
    libjack2
    libjpeg
    libmikmod
    libogg
    libpng12
    libpulseaudio
    librsvg
    libsamplerate
    libthai
    libtheora
    libtiff
    libudev0-shim
    libusb1
    libuuid
    libvdpau
    libvorbis
    libvpx
    libxcrypt-legacy
    libxkbcommon
    libxml2
    mesa
    nspr
    nss
    openssl
    p11-kit
    pango
    pixman
    python3
    speex
    stdenv.cc.cc
    tbb
    udev
    vulkan-loader
    wayland
    xorg.libICE
    xorg.libSM
    xorg.libX11
    xorg.libXScrnSaver
    xorg.libXcomposite
    xorg.libXcursor
    xorg.libXdamage
    xorg.libXext
    xorg.libXfixes
    xorg.libXft
    xorg.libXi
    xorg.libXinerama
    xorg.libXmu
    xorg.libXrandr
    xorg.libXrender
    xorg.libXt
    xorg.libXtst
    xorg.libXxf86vm
    xorg.libpciaccess
    xorg.libxcb
    xorg.xcbutil
    xorg.xcbutilimage
    xorg.xcbutilkeysyms
    xorg.xcbutilrenderutil
    xorg.xcbutilwm
    xorg.xkeyboardconfig
    xz
    zlib
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

  system.stateVersion = "24.11";

}
