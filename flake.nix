{
  description = "Maixnor's NixOs and Home-Manager configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/master";
		nixvim = {
			url = "github:nix-community/nixvim";
			inputs.nixpkgs.follows = "nixpkgs";
		};
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    firefox-addons = {
      url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-colors.url = "github:misterio77/nix-colors";
    stylix.url = "github:danth/stylix";
  };

  outputs = { self, nixpkgs, home-manager, nixvim, stylix, ... } @inputs :
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
				specialArgs = { inherit system; inherit inputs; inherit home-manager; };
				modules = [ ./bierbasis/configuration.nix ];
			};

			nixosConfigurations."bierzelt" = nixpkgs.lib.nixosSystem {
				specialArgs = { inherit system; inherit inputs; };
				modules = [ ./bierzelt/configuration.nix ];
			};

      homeConfigurations."bierbasis" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;

        modules = [ ./bierbasis/home.nix ];
        extraSpecialArgs = { inherit inputs; };
      };

      homeConfigurations."bierzelt" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;

        modules = [ ./bierzelt/home.nix ];
        extraSpecialArgs = { inherit inputs; };
      };
      
    };
}
