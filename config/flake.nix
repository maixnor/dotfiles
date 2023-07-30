{
  description = "My Configuration";

  outputs = { self, nixpkgs }: {

    nixosConfigurations.bierzelt = nixpkgs.obsidian;

  };
}
