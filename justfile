
home host: 
  export NIXPKGS_ALLOW_UNFREE=1 && home-manager switch --flake ~/repo/dotfiles#{{host}} --impure -b backup 

nixos host:
	sudo nixos-rebuild switch --flake ~/repo/dotfiles#{{host}} 

vm host:
	sudo nixos-rebuild build-vm --flake ~/repo/dotfiles#{{host}} 

bierzelt:
  just nixos bierzelt home bierzelt

bierbasis: 
  just nixos bierbasis home bierbasis

wieselburg: 
  just nixos wieselburg home wieselburg

