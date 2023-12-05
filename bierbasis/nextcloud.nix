
{ config, pkgs, ... }:

{

	environment.etc."nextcloud-admin-pass".text = "admin";
	services.nextcloud = {
	  enable = true;
	  package = pkgs.nextcloud27;
	  hostName = "localhost";
		configureRedis = true;
		maxUploadSize = "1G";
		config = {
	  	adminpassFile = "/etc/nextcloud-admin-pass";
			dbtype = "pgsql";
		};
		extraApps = with config.services.nextcloud.package.packages.apps; {
    	inherit news contacts calendar tasks onlyoffice notes deck;
  	};
  	extraAppsEnable = true;
	};

}
