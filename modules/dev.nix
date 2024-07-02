{ pkgs, config, ... }:

{
  config = {
    environment.systemPackages = with pkgs; [
      rustup
      bacon

      gcc

      dotnet-sdk_8
      dotnet-runtime_8
      dotnet-aspnetcore_8

      tectonic

      jdk
      eclipses.eclipse-java
    ];
  };
}
