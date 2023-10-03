{ pkgs, ... }:

let
  # tmux-super-fingers = pkgs.tmuxPlugins.mkTmuxPlugin
  #   {
  #     pluginName = "tmux-super-fingers";
  #     version = "unstable-2023-01-06";
  #     src = pkgs.fetchFromGitHub {
  #       owner = "artemave";
  #       repo = "tmux_super_fingers";
  #       rev = "2c12044984124e74e21a5a87d00f844083e4bdf7";
  #       sha256 = "sha256-cPZCV8xk9QpU49/7H8iGhQYK6JwWjviL29eWabuqruc=";
  #     };
  #   };
in
{
  programs.tmux = {
    enable = true;
    shell = "${pkgs.zsh}/bin/zsh";
    terminal = "tmux-256color";
    historyLimit = 100000;
    plugins = with pkgs;
      [
	{ 
	  plugin = tmuxPlugins.fingers;
	  extraConfig = "set -g @fingers-key F";
	}
        # {
        #   plugin = tmux-super-fingers;
        #   extraConfig = "set -g @super-fingers-key f";
        # }
        { 
	  plugin = tmuxPlugins.better-mouse-mode;
	  extraConfig = "";
	}
	{ 
	  plugin = tmuxPlugins.resurrect;
	  extraConfig = "set -g @resurrect-capture-pane-contents 'on'";
	}
	{ 
	  plugin = tmuxPlugins.continuum;
	  extraConfig = ''
	  set -g @continuum-restore 'on'
	  set -g @continuum-save-interval '1'
	  '';
	}
      ];
    extraConfig = ''
      set -g prefix C-a
      unbind C-b
      bind-key C-a send-prefix
      
      unbind %
      bind | split-window -h -c "#{pane_current_path}"
      
      unbind '"'
      bind - split-window -v -c "#{pane_current_path}"

      bind c new-window      -c "#{pane_current_path}"
      
      unbind r
      bind r source-file ~/.tmux.conf

      bind -r j resize-pane -D 5
      bind -r k resize-pane -U 5
      bind -r l resize-pane -R 5
      bind -r h resize-pane -L 5
      
      bind -r m resize-pane -Z

      set -g mode-keys vi
      
      bind-key -T copy-mode-vi 'v' send -X begin-selection # start selecting text with "v"
      bind-key -T copy-mode-vi 'y' send -X copy-selection # copy text with "y"
      
      unbind -T copy-mode-vi MouseDragEnd1Pane # don't exit copy mode when dragging with mouse
      
      # remove delay for exiting insert mode with ESC in Neovim
      set -sg escape-time 10
   '';
  };
}
