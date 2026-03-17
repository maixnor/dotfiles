{ lib, config, pkgs, ... }:

{

  programs = {
    direnv = {
      enable = true;
      enableBashIntegration = true; # see note on other shells below
      enableZshIntegration = true;
      nix-direnv.enable = true;
    };

    bash.enable = true; # see note on other shells below
    # zsh enabled below, everything is fine 
  };

  programs.ripgrep.enable = true;
  programs.bat.enable = true;

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    shellAliases = {
      g = "nvim -c Git -c only";
      nix-shell = "export NIXPKGS_ALLOW_UNFREE=1 && nix-shell ";
      ping = "gping";
      ps = "procs";
      ls = "lsd";
      diff = "delta";
      cd = "z";
    };
    initExtra = ''
      # Worktrunk shell integration
      eval "$(wt config shell init zsh)"
    '';
  };

	home.packages = with pkgs; [
    nix-zsh-completions

		fastfetch
    parallel
    wl-clipboard # wl-copy wl-paste

    bat fd ripgrep delta lsd dust duf # modern replacements
    choose sd cheat tldr gping procs # dog # modern replacements

    clang coreutils just inotify-tools
		jq jc jo gron yj yq pup # like jq but different formats
	];

  programs.starship.enable = true;
  programs.starship.settings = builtins.fromTOML (builtins.readFile ../starship.toml);

  # Worktrunk configuration
  xdg.configFile."worktrunk/config.toml".text = ''
    # Worktrunk configuration - managed by NixOS

    # Worktree path template - creates worktrees inside the repo
    # Alternative: "{{ repo_path }}/../{{ repo }}.{{ branch | sanitize }}" for sibling directories
    worktree-path = ".worktrees/{{ branch | sanitize }}"

    [list]
    # Show additional information in wt list
    full = false
    branches = false
    remotes = false

    [commit]
    # What to stage before commit: "all", "tracked", or "none"
    stage = "all"

    [merge]
    # Squash commits into one by default
    squash = true
    # Commit uncommitted changes before merging
    commit = true
    # Rebase onto target before merge
    rebase = true
    # Remove worktree after successful merge
    remove = true
    # Run project hooks during merge
    verify = true

    # Post-create hook: automatically allow direnv if .envrc exists
    [post-create]
    direnv = "test -f .envrc && direnv allow || true"

    # Uncomment and configure if you want LLM-generated commit messages
    # [commit.generation]
    # command = "claude -p --no-session-persistence --model=haiku"
  '';

}
