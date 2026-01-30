{ modulesPath, pkgs, nixvim, ... }:

let 
  hostname = "wieselburg";
in
{
  imports = [ 
    (modulesPath + "/installer/scan/not-detected.nix")
    (modulesPath + "/profiles/qemu-guest.nix")
    ./vpsadminos.nix # for vpsfree.cz
    ../modules/misc-server.nix
    ../modules/gh-auth.nix
    ../modules/zerotier.nix
    ../modules/content-factory-cli.nix
    ../services/autoupdate.nix
    ../services/traefik-base.nix
    ../services/maixnorcom.nix
    ../services/searx.nix
    ../services/languagebuddy.nix
    ../services/observability.nix
    ../services/content-factory.nix
    # ../services/ai-research.nix
    # ../services/nextcloud.nix
    ../services/immich.nix
    ../services/adhoc-tunnel.nix
    # ../services/audiobookshelf.nix
    # ../services/navidrome.nix
    # ../services/collabora.nix
  ];

  virtualisation.vmware.guest.enable = true;

  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.cores = 2;
  nix.settings.max-jobs = 1;

  systemd.services.nix-daemon.serviceConfig = {
    MemoryMax = "2G";
    MemoryHigh = "1900M";
  };

  nix.gc = {
    automatic = true;
    persistent = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  services.autoupdate.enable = true;
  services.autoupdate.webhook.domain = "wieselburg.maixnor.com";

  services.openssh.enable = true;
  services.openssh.settings.PermitRootLogin = "yes";
  services.openssh.authorizedKeysInHomedir = true;

  time.timeZone = "Europe/Amsterdam";

  swapDevices = [ {
    device = "/var/lib/swapfile";
    size = 4096; # 4GB
  } ];

  users.groups.maixnor = {};

  users.users.maixnor = let 
    keys = import ../modules/public-keys.nix;
  in {
    isNormalUser = true;
    group = "maixnor";
    extraGroups = [ "wheel" "immich" "web-static" ];
    openssh.authorizedKeys.keys = keys.users.maixnor;
    packages = [ nixvim ];
  };

  # Enable common container config files in /etc/containers
  virtualisation.containers.enable = true;
  virtualisation = {
    podman = {
      enable = true;
      dockerCompat = true;
      defaultNetwork.settings.dns_enabled = true;
    };
  };

  networking.hostName = "${hostname}";

  ### System Packages
  environment.systemPackages = with pkgs; [ 
    git just
    wormhole-william
    #appflowy
  ];

  ### User Configuration
  security.sudo.wheelNeedsPassword = false;
  nix.settings.trusted-users = [ "@wheel" "maixnor" "backup" ];

  system.stateVersion = "24.11";
}
