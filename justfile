
vm host:
	sudo nixos-rebuild build-vm --flake ~/repo/dotfiles#{{host}} 

bierzelt:
  just update bierzelt 

bierbasis: 
  just update bierbasis 

wieselburg: 
  just update wieselburg

