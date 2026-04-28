
update host:
	git pull && nh os switch .

vm host:
	sudo nixos-rebuild build-vm --flake ~/repo/dotfiles#{{host}} 

bierzelt:
  just remove-gtk
  just update bierzelt 

bierbasis: 
  just remove-gtk
  just update bierbasis 

wieselburg: 
  just update wieselburg

deploy-wieselburg:
  nixos-rebuild switch --flake .#wieselburg --target-host wieselburg.maixnor.com --sudo

ottakring:
  just update ottakring

deploy-ottakring:
  nixos-rebuild switch --flake .#ottakring --target-host 172.16.32.135 --sudo

remove-gtk:
  rm -rf ~/.gtk*

expire:
  sudo nix-collect-garbage --delete-older-than 7d
  nix-collect-garbage --delete-older-than 7d

