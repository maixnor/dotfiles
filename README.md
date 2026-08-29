> [!WARNING]
> This repository has been officially discontinued and will no longer be updated.
> I had to move my dotfiles to a private repository because a large portion of the configuration now contains private/professional data that cannot be published.
> For any questions regarding NixOS, past configurations, or their current evolution, visitors are highly encouraged to contact me directly or open an issue here. I am very happy to help and share insights!

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

