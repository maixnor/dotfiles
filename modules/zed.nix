{ lib, pkgs, ... }:
{
    programs.zed-editor = {
      enable = true;
      extensions = [ "nix" "ts" "rust" ];
      userSettings = {
        vim_mode = true;
        inactive_opactiy = 0.8;
        base_keymap = "JetBrains";
        relative_line_numbers = "enabled";
        theme = lib.mkDefault {
          mode = "dark";
          dark = "oxocarbon";
        };
        agent_servers = {
            gemini = {
                ignore_system_version = false;
            };
        };
      };
    };

    home.packages = with pkgs; [ gemini-cli ];
}
