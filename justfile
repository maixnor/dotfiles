
home host: 
  export NIXPKGS_ALLOW_UNFREE=1 && home-manager switch --flake ~/dotfiles#{{host}} --impure

nixos host:
	sudo nixos-rebuild switch --flake ~/dotfiles#{{host}}

