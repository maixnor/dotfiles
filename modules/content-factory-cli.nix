{ pkgs, lib, inputs, ... }:

let
  cf-pkgs = inputs.content-factory.packages.${pkgs.system};
  
  maya-package = cf-pkgs.maya-package;
  maya-cli = cf-pkgs.maya-cli;
  maya-publish = cf-pkgs.maya-publish;
  maya-migrate = cf-pkgs.maya-migrate;
  
  # For backward compatibility and for services/content-factory.nix
  cf-src = "${inputs.content-factory}";

in {
  environment.systemPackages = [
    maya-package
  ];

  # Expose the derivations for other modules to use if needed
  _module.args = {
    contentFactory = {
      inherit maya-cli maya-publish maya-migrate maya-package;
      cf-src = cf-src;
    };
  };
}