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
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    firefox-addons = {
      url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    fine-cmdline = {
      url = "github:VonHeikemen/fine-cmdline.nvim";
      flake = false;
    };
    impermanence.url = "github:nix-community/impermanence";
    nix-colors.url = "github:misterio77/nix-colors";
    stylix.url = "github:danth/stylix";
    nixpkgs-mozilla.url = "github:mozilla/nixpkgs-mozilla";
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, nixos-generators, ... } @inputs :
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { 
        inherit system;
        overlays = [ inputs.nixpkgs-mozilla.overlay ];
        config = {
            allowUnfree = true;
        };
      };

      nvim = inputs.nixvim.legacyPackages.${system}.makeNixvimWithModule {
        inherit pkgs;
        module = import ./modules/nixvim.nix;
        extraSpecialArgs = {};
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
        system = "x86_64-linux";
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

      packages.x86_64-linux = {
        linode = nixos-generators.nixosGenerate {
          system = "x86_64-linux";
          modules = [
            # you can include your own nixos configuration here, i.e.
            # ./configuration.nix
            ./linode/configuration.nix
          ];
          format = "linode";
        };
        nixvim = nvim;
      };
      
      packages.default = nvim;

      formatter = pkgs.nixfmt-rfc-style;

    };
}
