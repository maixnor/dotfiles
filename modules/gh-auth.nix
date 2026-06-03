{ config, pkgs, ... }:

{
  age.secrets.github = {
    file = ../secrets/github.age;
    owner = "maixnor";
  };

  age.secrets.github-nix-conf = {
    file = ../secrets/github-nix-conf.age;
    owner = "root";
    group = "root";
    mode = "0440";
  };

  # Make it available in the shell for gh CLI and other tools
  environment.extraInit = ''
    if [ -f /run/agenix/github ]; then
      export GITHUB_TOKEN=$(cat /run/agenix/github)
    fi
  '';

  nix.extraOptions = ''
    !include /run/agenix/github-nix-conf
  '';

  environment.systemPackages = [ pkgs.gh ];
}
