{ pkgs, config, ... }:

{

    home.packages = with pkgs; [
        obsidian
				openconnect
				gh
				wget xh
				freshfetch
				spotify
				discord
				btop
				pandoc
				ripgrep
				geogebra6
				parallel

				# kde
				kate
				okular
				spectacle
				kmail
				konsole

				# general development stuff
				vagrant
				fd clang coreutils just
				jq jc jo gron yj yq pup

				# unfree
    ];

}
