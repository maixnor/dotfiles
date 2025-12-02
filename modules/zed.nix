{ }:
{
    programs.zed-editor = {
      enable = true;
      extensions = [ "nix" "ts" "rust" ];
      userSettings = {
        vim_mode = true;
        inactive_opactiy = 0.8;
        base_keymap = "JetBrains";
        relative_line_numbers = "enabled";
      };
    };
}

