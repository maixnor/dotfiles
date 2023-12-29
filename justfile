
home host: 
  home-manager switch --flake ~/dotfiles#{{host}}

nixos host:
	sudo nixos-rebuild switch --flake ~/dotfiles#{{host}}

