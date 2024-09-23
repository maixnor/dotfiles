{
  description = "Maixnor's NixOs and Home-Manager configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/master";
		nixvim = {
			url = "github:nix-community/nixvim";
			inputs.nixpkgs.follows = "nixpkgs";
		};
    disko = { 
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    impermanence = { 
      url = "github:nix-community/impermanence";
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
    nixpkgs-mozilla.url = "github:mozilla/nixpkgs-mozilla";
  };

  outputs = { nixpkgs, home-manager, ... } @inputs :
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { 
        inherit system;
        overlays = [ inputs.nixpkgs-mozilla.overlay ];
        config = {
            allowUnfree = true;
        };
      };
# TODO build utility function with loop
    in {
      nixosConfigurations."bierbasis" = nixpkgs.lib.nixosSystem {
          specialArgs = { inherit system; inherit inputs; };
          modules = [ ./bierbasis/configuration.nix ];
      };

			nixosConfigurations."bierzelt" = nixpkgs.lib.nixosSystem {
				specialArgs = { inherit system; inherit inputs; };
				modules = [ ./bierzelt/configuration.nix ];
			};

			nixosConfigurations."wieselburg" = nixpkgs.lib.nixosSystem {
				specialArgs = { inherit system; inherit inputs; };
				modules = [ ./wieselburg/configuration.nix ];
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
      
      homeConfigurations."wieselburg" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [ ./wieselburg/home.nix ];
        extraSpecialArgs = { inherit inputs; };
      };
      
    };
}
