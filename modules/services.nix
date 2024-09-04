{ pkgs, config, lib, ... }:

{

  config = {
    services.searx.enable = true;
    services.searx.settings = {
      server.port = 6666;
      server.bind_address = "0.0.0.0";
      server.secret_key = "definetelysecret";
    };
  };

}
