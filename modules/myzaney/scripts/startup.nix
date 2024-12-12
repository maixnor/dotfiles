{ pkgs }:

pkgs.writeShellScriptBin "startup" ''
  # Start Obsidian and move to workspace 1
  obsidian &
  sleep 1  # Wait for Obsidian to start
  hyprctl dispatch workspace 1

  # Start Firefox and move to workspace 3
  firefox &
  sleep 1  # Wait for Firefox to start
  hyprctl dispatch workspace 3

  # Start Kitty and move to workspace 8
  kitty &
  sleep 1  # Wait for Kitty to start
  hyprctl dispatch workspace 8
''
