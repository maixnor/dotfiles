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
    base16-schemes = "github:maixnor/base16-schemes";
    nix-colors.url = "github:misterio77/nix-colors";
    nix-colors.inputs.base16-schemes.follows = "base16-schemes";

  };

  outputs = { nixpkgs, home-manager, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      homeConfigurations."bierzelt" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;

        modules = [ ./bierzelt.nix ];
	extraSpecialArgs = { inherit nix-colors };

        # Optionally use extraSpecialArgs
        # to pass through arguments to home.nix
      };
      
      homeConfigurations."bierbasis" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;

        modules = [ ./bierbasis.nix ];
	extraSpecialArgs = { inherit nix-colors };

        # Optionally use extraSpecialArgs
        # to pass through arguments to home.nix
      };
    };
}
