{ pkgs }:

pkgs.writeShellScriptBin "startup" ''
  # Start Obsidian and move to workspace 1
  sleep .5
  hyprctl dispatch workspace 1
  obsidian &
  sleep 2 # Wait for Obsidian to start

  # Start Firefox and move to workspace 3
  hyprctl dispatch workspace 3
  firefox &
  sleep 2 # Wait for Firefox to start

  # Start Kitty and move to workspace 8
  hyprctl dispatch workspace 8
  kitty &
  sleep 1 # Wait for Kitty to start
''
