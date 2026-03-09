{ config, lib, pkgs, ... }:

{
  # Import the full nixvim configuration
  imports = [ ./nixvim.nix ];

  # Override LSP settings to disable all servers
  plugins.lsp = lib.mkForce {
    enable = false;
  };

  # Disable LSP-dependent completion sources
  plugins.cmp.settings.sources = lib.mkForce [
    { name = "path"; }
    { name = "buffer"; }
  ];

  # Keep cmp-nvim-lsp disabled since we don't have LSP
  plugins.cmp-nvim-lsp.enable = lib.mkForce false;
}
