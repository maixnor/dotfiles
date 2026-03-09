{ config, pkgs, ... }:

{
  age.secrets.github = {
    file = ../secrets/github.age;
    owner = "maixnor";
  };

  # Make it available in the shell for gh CLI and other tools
  environment.extraInit = ''
    if [ -f /run/agenix/github ]; then
      export GITHUB_TOKEN=$(cat /run/agenix/github)
    fi
  '';

  environment.systemPackages = [ pkgs.gh ];
}
