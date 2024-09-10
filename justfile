
home host: 
  export NIXPKGS_ALLOW_UNFREE=1 && home-manager switch --flake ~/repo/dotfiles#{{host}} --impure -b backup --extra-experimental-features nix-command --extra-experimental-features flakes

nixos host:
	sudo nixos-rebuild switch --flake ~/repo/dotfiles#{{host}} 

nixos-vm host:
	sudo nixos-rebuild build-vm --flake ~/repo/dotfiles#{{host}} 

bierzelt:
  just nixos bierzelt home bierzelt

bierbasis: 
  just nixos bierbasis home bierbasis

wieselburg: 
  just nixos wieselburg home wieselburg

