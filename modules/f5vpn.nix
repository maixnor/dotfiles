{

  description = "A configurable VPN connection using f5 Big IP VPN";

  inputs.f5fpc.url = "https://vpn.mtu.edu/public/download/linux_sslvpn.tgz";
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }: {
    defaultPackage.x86_64-linux = 
      with import nixpkgs { system = "x86_64-linux"; };
      stdenv.mkDerivation {
	name = f5fpc;
	src = self;
	buildPhase = "tar -xfz linux_sslvpn.tgz";
	installPhase = ''yes "yes" | ./Install.sh && rm -rf /tmp/f5fpc'';
      };
  };

}
