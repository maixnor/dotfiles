{ config, lib, pkgs, ... }:

let
  cfg = config.programs.barracudavpn;

  barracudavpnPackage = pkgs.stdenv.mkDerivation rec {
    pname = "barracudavpn";
    version = cfg.version;

    src = if cfg.src != null then cfg.src else pkgs.requireFile {
      name = "barracudavpn_${version}_amd64.deb";
      sha256 = cfg.sha256;
      url = "https://dlportal.barracudanetworks.com/";
      message = ''
        This package requires the Barracuda VPN Client Debian package.
        Please download 'barracudavpn_${version}_amd64.deb' from the Barracuda Download Portal
        (NAC / VPN Client -> Barracuda VPN Client for Linux) and add it to the Nix store using:
        nix-store --add-fixed sha256 barracudavpn_${version}_amd64.deb
      '';
    };

    nativeBuildInputs = [ pkgs.dpkg pkgs.autoPatchelfHook ];

    buildInputs = [
      pkgs.stdenv.cc.cc.lib
      pkgs.zlib
      pkgs.openssl
      pkgs.libxcrypt
      pkgs.readline
      pkgs.pam
      pkgs.openldap
    ];

    dontConfigure = true;
    dontBuild = true;

    unpackPhase = ''
      runHook preUnpack
      dpkg -x $src .
      runHook postUnpack
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out/bin
      if [ -f usr/local/bin/barracudavpn ]; then
        cp usr/local/bin/barracudavpn $out/bin/barracudavpn
      elif [ -f usr/bin/barracudavpn ]; then
        cp usr/bin/barracudavpn $out/bin/barracudavpn
      else
        echo "Could not find barracudavpn binary in the extracted files!"
        exit 1
      fi
      chmod +x $out/bin/barracudavpn
      runHook postInstall
    '';

    meta = with lib; {
      description = "Barracuda VPN Client for Linux";
      homepage = "https://campus.barracuda.com/product/networkaccessclient";
      license = licenses.unfree;
      platforms = [ "x86_64-linux" ];
    };
  };

in {
  options.programs.barracudavpn = {
    enable = lib.mkEnableOption "Barracuda VPN Client";
    
    version = lib.mkOption {
      type = lib.types.str;
      default = "5.3.6";
      description = "Version of the Barracuda VPN client.";
    };

    sha256 = lib.mkOption {
      type = lib.types.str;
      default = "1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"; # dummy hash, must be overridden if requireFile is used
      description = "SHA-256 hash of the downloaded debian package.";
    };

    src = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Optional path to the locally downloaded debian package, bypassing requireFile.";
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = barracudavpnPackage;
      description = "The package to use.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    security.wrappers.barracudavpn = {
      owner = "root";
      group = "root";
      source = "${cfg.package}/bin/barracudavpn";
      setuid = true;
    };
  };
}
