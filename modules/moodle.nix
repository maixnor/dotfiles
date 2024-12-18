{ pkgs, lib }:

{

  services.moodle = {
    enable = true;
    initialPassword = "nicolasolsa";
    database.createLocally = true;
    virtualHost = {
      listen."6080".ip = true;
      hostName = "localhost:6080";
      adminAddr = "severin.heugabler@gmail.com";
      forceSSL = true;
      enableACME = true;
    };
  };
}

