{
  description = "Maixnor's nix configuration flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };


  outputs = { self, nixpkgs }:

  let 
    system = "x86_64-linux";

    pkgs = import nixpkgs {
      inherit system;
      config = {
        allowUnfree = true;
      };
    };

  in {
    nixosConfigurations = {
      bierzelt = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit system; };
        modules = [
          ./nixos/configuration.nix
# 	  ./hyprland/flake.nix
        ];
      };
    };
  };
	  
}
