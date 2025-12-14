{ pkgs, ... }:

{
  home.packages = with pkgs; [
    gemini-cli
  ];

  home.file.".gemini/settings.json".text = builtins.toJSON {
    mcpServers = {
      "context7" = {
        command = "${pkgs.nodejs}/bin/npx";
        args = [ "-y" "@upstash/context7-mcp" ];
      };
    };
  };
}
