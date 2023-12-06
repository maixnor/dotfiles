
{ config, pkgs, ... }:

{

	environment.etc."nextcloud-admin-pass".text = "admin";

	services.nextcloud = {
	  enable = true;
	  package = pkgs.nextcloud27;
	  hostName = "localhost";
		configureRedis = true;
		maxUploadSize = "1G";
		database.createLocally = true;
		config = {
	  	adminpassFile = "/etc/nextcloud-admin-pass";
			dbtype = "pgsql";
			defaultPhoneRegion = "AT";
		};
		extraApps = with config.services.nextcloud.package.packages.apps; {
    	inherit news contacts calendar tasks onlyoffice notes deck;
  	};
  	extraAppsEnable = true;
		autoUpdateApps.enable = true;
	};

	# services.onlyoffice = {
  #   enable = true;
  #   hostname = "localhost";
  # };

}
