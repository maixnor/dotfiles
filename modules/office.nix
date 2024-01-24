{ pkgs, ... }:

{
	home.packages = with pkgs; [ 
    libreoffice-fresh
    hunspell
    hunspellDicts.sv_SE
    hunspellDicts.en_US-large
    hunspellDicts.de_AT
  ];
}
