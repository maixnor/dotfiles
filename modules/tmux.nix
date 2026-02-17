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
          extraConfig = "set -g @thumbs-key M-f";
        }
        { 
          plugin = fuzzback;
          extraConfig = "set -g @fuzzback-bind M-b";
        }
        {
          plugin = session-wizard;
          extraConfig = "set -g @session-wizard 'M-e'";
        }
        { 
          plugin = tmux-fzf;
          extraConfig = ''TMUX_FZF_LAUNCH_KEY="M-t"'';
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
      
      # Global Alt Bindings (No Prefix)
      bind-key -n M-c new-window      -c "#{pane_current_path}"
      bind-key -n M-| split-window -h -c "#{pane_current_path}"
      bind-key -n M-- split-window -v -c "#{pane_current_path}"
      bind-key -n M-m resize-pane -Z
      bind-key -n M-r source-file ~/.config/tmux/tmux.conf
      bind-key -n M-g display-popup -d "#{pane_current_path}" -w 90% -h 90% -E "nvim -c Git -c only"
      
      # Copy/Paste
      bind-key -n M-[ copy-mode
      bind-key -n M-] paste-buffer

      # Resizing (Alt + hjkl)
      bind-key -n M-j resize-pane -D 5
      bind-key -n M-k resize-pane -U 5
      bind-key -n M-l resize-pane -R 5
      bind-key -n M-h resize-pane -L 5

      set -g mode-keys vi
      set -g status off
      
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
