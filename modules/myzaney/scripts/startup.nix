{ pkgs }:

pkgs.writeShellScriptBin "startup" ''
  tmux start-server
  # Start Obsidian and move to workspace 1
  sleep .5
  hyprctl dispatch workspace 1
  obsidian &
  sleep 2 # Wait for Obsidian to start

  # Start browser and move to workspace 3
  hyprctl dispatch workspace 3
  librefolf &
  sleep 2 # Wait for browser to start

  # Start Kitty and move to workspace 8
  hyprctl dispatch workspace 8
  alacritty &
  sleep 1 # Wait for Kitty to start
  # start open-webui container on bierzelt
  docker start 44bb
''
