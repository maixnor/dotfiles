{
  description = "Maixnor's nix configuration flake";

  inputs = {
    # nixpkgs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # Home Manager
    home-manager.url = "github:nix-community/home-manager/release-23.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # Doom Emacs 
    # probabyly add doom emacs reference here

  };


  outputs = { self, nixpkgs, home-manager }@inputs:

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
	  ./home/flake.nix
# 	  ./hyprland/flake.nix
        ];
      };
    };

    homeConfigurations = {
      "maixnor@bierzelt" = home-manager.lib.homeManagerConfiguration {
	extraSpecialArgs = { inherit inputs; };
	modules = [ ./home/home.nix ];
      };
    };
  };
	  
}
