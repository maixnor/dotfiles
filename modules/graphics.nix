{ pkgs, config, ... }:

{
    home.packages = with pkgs; [
				wayland-utils
				xorg.xwininfo
				vulkan-tools
				glxinfo
				clinfo
    ];
}
