
home host: 
  export NIXPKGS_ALLOW_UNFREE=1 && home-manager switch --flake ~/dotfiles#{{host}} --impure -b backup

nixos host:
	sudo nixos-rebuild switch --flake ~/dotfiles#{{host}}

bierzelt:
  just nixos bierzelt home bierzelt

bierbasis: 
  just nixos bierbasis home bierbasis

