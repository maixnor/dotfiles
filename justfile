
home host: 
  export NIXPKGS_ALLOW_UNFREE=1 && home-manager switch --flake ~/repo/dotfiles#{{host}} --impure -b backup 

nixos host:
	sudo nixos-rebuild switch --flake ~/repo/dotfiles#{{host}} 

vm host:
	sudo nixos-rebuild build-vm --flake ~/repo/dotfiles#{{host}} 

anywhere-vm host:
  nix run github:nix-community/nixos-anywhere -- --flake ~/repo/dotfiles#{{host}} --vm-test

anywhere host usr ip:
  nix run github:nix-community/nixos-anywhere -- --flake ~/repo/dotfiles#{{host}} {{usr}}@{{ip}} --disko-mode format

bierzelt:
  just nixos bierzelt home bierzelt

bierbasis: 
  just nixos bierbasis home bierbasis

wieselburg: 
  just nixos wieselburg home wieselburg

