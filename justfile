
update host:
	git pull && sudo nixos-rebuild switch --flake ~/repo/dotfiles#{{host}}

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

cf-check:
  cd content-factory && nix-shell shell.nix --run "python3 -m py_compile *.py"

remove-gtk:
  rm -rf ~/.gtk*

