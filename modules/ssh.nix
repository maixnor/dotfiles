{ config, pkgs, lib, ... }:

{
  # Ensure ksshaskpass is available
  home.packages = [ pkgs.kdePackages.ksshaskpass ];

  # Point agenix to the identity file
  age.identityPaths = [ "${config.home.homeDirectory}/.ssh/id_ed25519" ];

  # Configure SSH to use ksshaskpass
  home.sessionVariables = {
    SSH_ASKPASS = "${pkgs.kdePackages.ksshaskpass}/bin/ksshaskpass";
    # Some tools specifically look for this without the path
    SSH_ASKPASS_REQUIRE = "prefer";
  };

  # SSH client configuration to automatically add keys to agent
  programs.ssh = {
    enable = true;
    extraConfig = ''
      AddKeysToAgent yes
    '';
  };

  # Autostart ssh-add on Plasma login
  # This uses the Plasma-specific autostart directory
  xdg.configFile."autostart/ssh-add.desktop".text = ''
    [Desktop Entry]
    Exec=ssh-add ${config.home.homeDirectory}/.ssh/id_ed25519 < /dev/null
    Name=ssh-add
    Type=Application
    X-KDE-AutostartScript=true
  '';

  # Ensure the SSH agent is running as a user service
  services.ssh-agent.enable = true;
}
