
home host: 
  home-manager switch --flake ~/dotfiles#{{host}} --impure

nixos host:
	sudo nixos-rebuild switch --flake ~/dotfiles#{{host}}

