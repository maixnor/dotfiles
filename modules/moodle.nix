{ pkgs, lib, ... }:

{

  services.moodle = {
    enable = true;
    initialPassword = "topsecret";
    database.createLocally = true;
    virtualHost = {
      hostName = "localhost:80";
      adminAddr = "benjamin@meixner.org";
      #forceSSL = true;
      #enableACME = true;
    };
  };

  #security.acme.acceptTerms = true;
  #security.acme.defaults.email = "benjamin@meixner.org";
}

