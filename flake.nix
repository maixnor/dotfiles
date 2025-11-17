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

      nixvim = inputs.nixvim.legacyPackages.${system}.makeNixvimWithModule {
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
        specialArgs = { inherit system; inherit inputs; inherit nixvim; };
        modules = [ ./bierzelt/configuration.nix ];
      };

      nixosConfigurations."wieselburg" = nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
        specialArgs = { inherit system; inherit inputs; inherit nixvim; };
        modules = [ ./wieselburg/configuration.nix ];
      };

      nixosConfigurations."wieselburg-vm-test" = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit system; inherit inputs; inherit nixvim; };
        modules = [ ./wieselburg/vm-test.nix ];
      };

      homeConfigurations."bierbasis" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [ ./bierbasis/home.nix ];
        extraSpecialArgs = { inherit inputs; inherit nixvim; };
      };

      homeConfigurations."bierzelt" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [ ./bierzelt/home.nix ];
        extraSpecialArgs = { inherit inputs; inherit nixvim; };
      };
      
      homeConfigurations."wieselburg" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [ ./wieselburg/home.nix ];
        extraSpecialArgs = { inherit inputs; };
      };

      packages.x86_64-linux = {
        default = nixvim;
        nixvim = nixvim;
        wieselburg-vm-test = inputs.self.nixosConfigurations.wieselburg-vm-test.config.system.build.vm;
      };

      apps.x86_64-linux = {
        default = {
          type = "app";
          program = "${nixvim}/bin/nvim";
        };
        wieselburg-vm-test = {
          type = "app";
          program = let
            vmSystem = nixpkgs.lib.nixosSystem {
              system = "x86_64-linux";
              specialArgs = { inherit system; inherit inputs; inherit nixvim; };
              modules = [ ./wieselburg/vm-test.nix ];
            };
          in "${vmSystem.config.system.build.vm}/bin/run-wieselburg-vm-test-vm";
        };
      };
      
      formatter.x86_64-linux = pkgs.nixfmt-rfc-style;
    };
}
