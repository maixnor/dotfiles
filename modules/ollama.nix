{ pkgs, config, ... }:

{

    home.packages = with pkgs; [
				ollama
    ];

}
