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
    ../modules/zerotier.nix
    ../services/autoupdate.nix
    ../services/traefik-base.nix
    ../services/maixnorcom.nix
    ../services/searx.nix
    ../services/languagebuddy.nix
    ../services/observability.nix
    # ../services/ai-research.nix
    # ../services/nextcloud.nix
    ../services/immich.nix
    # ../services/audiobookshelf.nix
    # ../services/navidrome.nix
    # ../services/collabora.nix
  ];

  virtualisation.vmware.guest.enable = true;

  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.cores = 3;

  nix.gc = {
    automatic = true;
    persistent = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  services.autoupdate = {
    enable = true;
    hostname = "${hostname}";
  };

  services.openssh.enable = true;
  services.openssh.settings.PermitRootLogin = "yes";
  services.openssh.authorizedKeysInHomedir = true;

  services.nginx.enable = true;

  services.nginx.virtualHosts."languagebuddy.maixnor.com" = {
    root = "/var/www/languagebuddy/web";
    locations."/" = {
      extraConfig = ''
        proxy_hide_header Content-Security-Policy;
        proxy_hide_header X-Frame-Options;
      '';
    };
    extraConfig = ''
      labels = {
        "traefik.enable" = "true";
        "traefik.http.routers.languagebuddy-frontend.rule" = "Host(`languagebuddy.maixnor.com`)";
        "traefik.http.routers.languagebuddy-frontend.entrypoints" = "websecure";
        "traefik.http.routers.languagebuddy-frontend.tls.certresolver" = "letsencrypt";
        "traefik.http.services.languagebuddy-frontend.loadbalancer.server.port" = "80"; # Nginx typically listens on 80 by default
      };
    '';
  };

  time.timeZone = "Europe/Amsterdam";

  users.groups.maixnor = {};

  users.users.maixnor = {
    isNormalUser = true;
    group = "maixnor";
    extraGroups = [ "wheel" "immich" ];
    openssh.authorizedKeys.keys = [
      # bierzelt
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCwGqcBJ6aOYBilComuDTG6iW1z5FJ9I8rGgWhP3sUxHrpd47evuEuDDDfen7TkldtbvIQrbhWJ90Um6kCaKsEFh6kMUvraHLaqcd0dMSs9/xovRhPWmpVsGnnwjtDbxCvjEdoUgt28eRhn/CBjaprg4JYNWtrVbIdcjIL7Aho915G913QGK85qWzhx6eqomZpvNB90CbFHH6gtbRiQzwLO65SuOeJHa4iJ205JM7ivJduOgvyV1agYcxuh8MDWQpCsLUfrKsUYnm8o+NqcCHUc7/kCxgHXdC1QEc4m0ralTI9GoUuaY7z428YjjsM61cQuM3vmiDGakitJ7zWXBQ7avYHAFPbWHRXFqR6SGB3yxMExXTtYVvPBXaSbAMYPZeX0UMyLBZZLMCQf7eUm3zKH4z7wmMoPdiKGMkx0obhxQqtDCgYLj9ixqMwJvuzHhfB38vAkbP64ikhTx5uCTf1WuC4/C8wuVX14sESQxAMJvDwe+A83EFzZyaMx5MsCWlnvs42ygYKGBQ/Bfy6YrGviR+ePtiBHyUB1elaTH9kIMm17/MUOiu7HpA+88XuNaIQ9DpXpFv8uE/X/7aju1f5F8Qxj1tly7EEtiv2QfS5j1g0AmftgEPQu93WCABE6+DSoGmwZuxIquhhuskWXLWasJPXcBM5fMvVgBclSKbOb9w== maixnor@bierzelt"
    ];
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
    git gh just
    wormhole-william
    #appflowy
  ];

  ### User Configuration
  security.sudo.wheelNeedsPassword = false;
  nix.settings.trusted-users = [ "@wheel" "maixnor" "backup" ];

  system.stateVersion = "24.11";
}
