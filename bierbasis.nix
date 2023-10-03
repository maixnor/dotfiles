{ config, pkgs, ... }:

{
  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home.username = "maixnor";
  home.homeDirectory = "/home/maixnor";

  targets.genericLinux.enable = true;
  nixpkgs.config.allowUnfree = true;

  # This value determines the Home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new Home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update Home Manager without changing this value. See
  # the Home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "23.05";

  home.sessionVariables = {
    EDITOR = "nvim";
    LANG = "en_US.UTF-8";
  };

  home.packages = [
    pkgs.zoxide
  ];

  programs.zsh = {
    enable = true;
    enableAutosuggestions = true;
    enableCompletion = true;
    zplug = {
      enable = true;
      plugins = [ 
        { name = "zsh-users/zsh-autosuggestions"; }
      ];
    };
  };

  #TODO need to port the whole starship config here or at least integrate the file into this repo
  programs.starship.enable = true;

  home.file = {
    ".local/share/zsh/nix-zsh-completions".source =
      "${pkgs.nix-zsh-completions}/share/zsh/plugins/nix";
    "starship.toml".text = ''
      ## FIRST LINE/ROW: Info & Status
      # First param ─┌
      [username]
      format = " [╭─$user]($style)@"
      show_always = true
      style_root = "bold red"
      style_user = "bold red"
      
      # Second param
      [hostname]
      disabled = false
      format = "[$hostname]($style) in "
      ssh_only = false
      style = "bold dimmed red"
      trim_at = "-"
      
      # Third param
      [directory]
      style = "purple"
      truncate_to_repo = true
      truncation_length = 0
      truncation_symbol = "repo: "
      
      # Fourth param
      [sudo]
      disabled = false
      
      # Before all the version info (python, nodejs, php, etc.)
      [git_status]
      ahead = "⇡''${count}"
      behind = "⇣''${count}"
      deleted = "x"
      diverged = "⇕⇡''${ahead_count}⇣''${behind_count}"
      style = "white"
      
      # Last param in the first line/row
      [cmd_duration]
      disabled = false
      format = "took [$duration]($style)"
      min_time = 1
      
      
      ## SECOND LINE/ROW: Prompt
      # Somethere at the beginning
      [battery]
      charging_symbol = ""
      disabled = true
      discharging_symbol = ""
      full_symbol = ""
      
      [[battery.display]]  # "bold red" style when capacity is between 0% and 10%
      disabled = false
      style = "bold red"
      threshold = 15
      
      [[battery.display]]  # "bold yellow" style when capacity is between 10% and 30%
      disabled = true
      style = "bold yellow"
      threshold = 50
      
      [[battery.display]]  # "bold green" style when capacity is between 10% and 30%
      disabled = true
      style = "bold green"
      threshold = 80
      
      # Prompt: optional param 1
      [time]
      disabled = true
      format = " 🕙 $time($style)\n"
      style = "bright-white"
      time_format = "%T"
      
      # Prompt: param 2
      [character]
      error_symbol = " [×](bold red)"
      success_symbol = " [╰─λ](bold red)"
      
      # SYMBOLS
      [status]
      disabled = false
      format = '[\[$symbol$status_common_meaning$status_signal_name$status_maybe_int\]]($style)'
      map_symbol = true
      pipestatus = true
      symbol = "🔴"
      
      [aws]
      symbol = " "
      
      [conda]
      symbol = " "
      
      [dart]
      symbol = " "
      
      [docker_context]
      symbol = " "
      
      [elixir]
      symbol = " "
      
      [elm]
      symbol = " "
      
      [git_branch]
      symbol = " "
      
      [golang]
      symbol = " "
      
      [hg_branch]
      symbol = " "
      
      [java]
      symbol = " "
      
      [julia]
      symbol = " "
      
      [nim]
      symbol = " "
      
      [nix_shell]
      symbol = " "
      
      [nodejs]
      symbol = " "
      
      [package]
      symbol = " "
      
      [perl]
      symbol = " "
      
      [php]
      symbol = " "
      
      [python]
      symbol = " "
      
      [ruby]
      symbol = " "
      
      [rust]
      symbol = " "
      
      [swift]
      symbol = "ﯣ "

    '';
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
  programs.git = {
    enable = true;
    userName = "maixnor";
    userEmail = "46966993+maixnor@users.noreply.github.com";
  };
}