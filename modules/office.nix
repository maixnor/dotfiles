{ pkgs, ... }:

{
	home.packages = with pkgs; [ 
    libreoffice-qt
    hunspell
    hunspellDicts.sv_SE
    hunspellDicts.en_US-large
    hunspellDicts.de_AT
  ];

  home.sessionVariables = {
    SAL_USE_VCLPLUGIN = "kf5";
  };
}
