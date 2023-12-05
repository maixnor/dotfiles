{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nix-doom-emacs.url = "github:nix-community/nix-doom-emacs";
  };
  
  outputs = {
    self,
    nixpkgs,
    nix-doom-emacs,
    ...
  }: {
    nixosConfigurations.bierzelt = nixpkgs.lib.nixosSystem rec {
      system  = "x86_64-linux";
      modules = [
        { 
          environment.systemPackages = 
            let
              doom-emacs = nix-doom-emacs.packages.${system}.default.override {
                doomPrivateDir = ./doom.d;
              };
            in [
              doom-emacs
            ];
        }
        # ...
      ];
    };
  };
}
