
# Enter the Maixnor Realm

My home-manager and system configuration conveniently packaged into nix flakes.

### Install home-manager

```
nix shell github:NixOS/nixpkgs#home-manager --command home-manager switch --flake github:maixnor/dotfiles#bierbasis
```

### Maintenance

To remove all generations older than 30 days:

**NixOS (System):**
```bash
sudo nix-collect-garbage --delete-older-than 30d
```

**Home Manager (User):**
```bash
nix-collect-garbage --delete-older-than 30d
```


