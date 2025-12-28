{ pkgs, ... }:

{

  systemd.user.services.tmux-cleanup = {
    Unit = {
      Description = "Clean up unnamed tmux sessions";
    };
    Service = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "tmux-cleanup" ''
        #!/usr/bin/env bash
        # Get list of all sessions and remove those with numeric-only names (default tmux naming)
        ${pkgs.tmux}/bin/tmux list-sessions -F '#{session_name}' 2>/dev/null | while read -r session; do
          # Check if session name is a number (unnamed/default sessions)
          if [[ "$session" =~ ^[0-9]+$ ]]; then
            echo "Removing unnamed session: $session"
            ${pkgs.tmux}/bin/tmux kill-session -t "$session" 2>/dev/null || true
          fi
        done
      '';
    };
  };

  systemd.user.timers.tmux-cleanup = {
    Unit = {
      Description = "Daily cleanup of unnamed tmux sessions";
    };
    Timer = {
      OnCalendar = "daily";
      Persistent = true;
    };
    Install = {
      WantedBy = [ "timers.target" ];
    };
  };

  programs.tmux = {
    enable = true;
    shell = "${pkgs.zsh}/bin/zsh";
    terminal = "tmux-256color";
    historyLimit = 100000;
    newSession = true;
		clock24 = true;
    plugins = with pkgs.tmuxPlugins;
      [
				{ 
				  plugin = tmux-thumbs;
				  extraConfig = "set -g @thumbs-key F";
				}
				{ 
				  plugin = fuzzback;
				  extraConfig = "set -g @fuzzback-bind k";
				}
        {
          plugin = session-wizard;
          extraConfig = "set -g @session-wizard 'e'";
        }
				{ 
				  plugin = tmux-fzf;
				  extraConfig = ''TMUX_FZF_LAUNCH_KEY="tab"'';
				}
			  { 
				  plugin = better-mouse-mode;
				  extraConfig = "";
				}
				{ 
				  plugin = resurrect;
				  extraConfig = "set -g @resurrect-capture-pane-contents 'on'";
				}
				{ 
				  plugin = continuum;
				  extraConfig = ''
						set -g @continuum-restore 'on'
						set -g @continuum-save-interval '1'
				  '';
				}
        vim-tmux-navigator
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
      set -g status off
			# set -g status-position top
      
      bind-key -T copy-mode-vi 'v' send -X begin-selection # start selecting text with "v"
      bind-key -T copy-mode-vi 'y' send -X copy-selection # copy text with "y"
      
      unbind -T copy-mode-vi MouseDragEnd1Pane # don't exit copy mode when dragging with mouse
      
      # remove delay for exiting insert mode with ESC in Neovim
      set -sg escape-time 10

      set -g focus-events on

			# true colors for Neovim
			set-option -a terminal-features 'alacritty:RGB'
   '';
  };
}
