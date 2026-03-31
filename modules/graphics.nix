{ pkgs, config, ... }:

{
    home.packages = with pkgs; [
				wayland-utils
				vulkan-tools
				mesa-demos
				clinfo
    ];
}
