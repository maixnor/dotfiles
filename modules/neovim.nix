{ pkgs, stdenv, ... }:
let
  nvchad = stdenv.mkDerivation {
    pname = "nvchad";
    version = "";
    dontBuild = true;

    src = pkgs.fetchFromGitHub {
      owner = "NvChad";
      repo = "NvChad";
      rev = "6f25b2739684389ca69ea8229386c098c566c408";
      sha256 = "sha256-J4SGwo/XkKFXvq+Va1EEBm8YOQwIPPGWH3JqCGpFnxY=";
    };

    installPhase = ''
      # Fetch the whole repo and put it in $out
      mkdir $out
      cp -aR $src/* $out/
    '';
    };
in
{
  programs = {
    neovim = {
      enable = true;
      defaultEditor = true;
      viAlias = true;
      vimAlias = true;
    };
  };

  xdg.configFile."nvim/" = {
    source = nvchad;
  };
}
