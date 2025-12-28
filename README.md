
# Enter the Maixnor Realm

My home-manager and system configuration conveniently packaged into nix flakes.

### Install home-manager

```
nix shell github:NixOS/nixpkgs#home-manager --command home-manager switch --flake github:maixnor/dotfiles#bierbasis
```

### Maintenance

To remove all generations older than 30 days:

```sh
sudo nix profile wipe-history --profile /nix/var/nix/profiles/system --older-than 30d
sudo nix-collect-garbage --delete-older-than 30d
```

