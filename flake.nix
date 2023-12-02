{
  description = "Home Manager configuration of maixnor";

  inputs = {
    # Specify the source of Home Manager and Nixpkgs.
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # everything colors and styling
    nix-colors.url = "github:misterio77/nix-colors";

  };

  outputs = { self, nixpkgs, home-manager, ... } @inputs :
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { 
				inherit system;

				config = {
					allowUnfree = true;
				};
			};
    in {

			nixosConfigurations."bierbasis" = nixpkgs.lib.nixosSystem {
				specialArgs = { inherit system; };
				modules = [ ./bierbasis/configuration.nix ];
			};

      homeConfigurations."bierzelt" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;

        modules = [ ./bierzelt.nix ];
        extraSpecialArgs = { inherit inputs; };
      };
      
      homeConfigurations."bierbasis" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;

        modules = [ ./bierbasis/home.nix ];
        extraSpecialArgs = { inherit inputs; };
      };
    };
}
