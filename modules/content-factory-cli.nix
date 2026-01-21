{ pkgs, lib, inputs, ... }:

let
  cf-pkgs = inputs.content-factory.packages.${pkgs.system};
  
  maya-cli = cf-pkgs.maya-cli;
  maya-publish = cf-pkgs.maya-publish;
  maya-migrate = cf-pkgs.maya-migrate;
  
  # For backward compatibility with services/content-factory.nix if it expects certain attributes
  cf-src = "${inputs.content-factory}";

in {
  environment.systemPackages = [
    maya-cli
    maya-publish
    maya-migrate
  ];

  # Expose the derivations for other modules to use if needed
  _module.args = {
    contentFactory = {
      inherit maya-cli maya-publish maya-migrate;
      cf-src = cf-src;
    };
  };
}