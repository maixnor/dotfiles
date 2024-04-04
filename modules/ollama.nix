{ pkgs, config, ... }:

{
  home.packages = with pkgs; [
    (ollama.override { acceleration = "cuda"; })
    kdePackages.alpaka
  ];

#  systemd.services.ollama = {
#    description = "Ollama Service";
#    wantedBy = [ "multi-user.target" ];
#    serviceConfig = {
#      ExecStart = "${pkgs.ollama}/bin/ollama serve";  # Adjust the path as needed
#      WorkingDirectory = "/tmp/ollama";
#      Restart = "always";
#    };
#  };
}
