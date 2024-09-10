{ pkgs, ... }:

{

  programs.tmux = {
    enable = true;
    shell = "${pkgs.zsh}/bin/zsh";
    terminal = "tmux-256color";
    historyLimit = 100000;
    newSession = true;
		clock24 = true;
    plugins = with pkgs;
      [
				{ 
				  plugin = tmuxPlugins.tmux-thumbs;
				  extraConfig = "set -g @thumbs-key F";
				}
				{ 
				  plugin = tmuxPlugins.fuzzback;
				  extraConfig = "set -g @fuzzback-bind k";
				}
        {
          plugin = tmuxPlugins.session-wizard;
          extraConfig = "set -g @session-wizard 'e'";
        }
				{ 
				  plugin = tmuxPlugins.tmux-fzf;
				  extraConfig = ''TMUX_FZF_LAUNCH_KEY="tab"'';
				}
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
      set -g prefix C-n
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
			set -g status-position top
      
      bind-key -T copy-mode-vi 'v' send -X begin-selection # start selecting text with "v"
      bind-key -T copy-mode-vi 'y' send -X copy-selection # copy text with "y"
      
      unbind -T copy-mode-vi MouseDragEnd1Pane # don't exit copy mode when dragging with mouse
      
      # remove delay for exiting insert mode with ESC in Neovim
      set -sg escape-time 10

      set -g focus-events on

      # vim-tmux-navigator
      is_vim="ps -o state= -o comm= -t '#{pane_tty}' \
          | grep -iqE '^[^TXZ ]+ +(\\S+\\/)?g?(view|l?n?vim?x?|fzf)(diff)?$'"
      bind-key -n 'C-h' if-shell "$is_vim" 'send-keys C-h'  'select-pane -L'
      bind-key -n 'C-j' if-shell "$is_vim" 'send-keys C-j'  'select-pane -D'
      bind-key -n 'C-k' if-shell "$is_vim" 'send-keys C-k'  'select-pane -U'
      bind-key -n 'C-l' if-shell "$is_vim" 'send-keys C-l'  'select-pane -R'
      tmux_version='$(tmux -V | sed -En "s/^tmux ([0-9]+(.[0-9]+)?).*/\1/p")'
      if-shell -b '[ "$(echo "$tmux_version < 3.0" | bc)" = 1 ]' \
          "bind-key -n 'C-\\' if-shell \"$is_vim\" 'send-keys C-\\'  'select-pane -l'"
      if-shell -b '[ "$(echo "$tmux_version >= 3.0" | bc)" = 1 ]' \
          "bind-key -n 'C-\\' if-shell \"$is_vim\" 'send-keys C-\\\\'  'select-pane -l'"
      
      bind-key -T copy-mode-vi 'C-h' select-pane -L
      bind-key -T copy-mode-vi 'C-j' select-pane -D
      bind-key -T copy-mode-vi 'C-k' select-pane -U
      bind-key -T copy-mode-vi 'C-l' select-pane -R
      bind-key -T copy-mode-vi 'C-\' select-pane -l

			# true colors for Neovim
			set-option -sa terminal-features ',XXX:RGB'
   '';
  };
}
