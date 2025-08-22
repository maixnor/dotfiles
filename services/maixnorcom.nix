
{ pkgs, ... }:

{
  services.nginx.virtualHosts."maixnor.com" = {
    serverAliases = [ "wieselburg.maixnor.com" "wb.maixnor.com" ];
    addSSL = true;
    enableACME = true;
    root = "/var/www/maixnor.com";
  };

  # Static file server with directory browsing
  services.nginx.virtualHosts."static.maixnor.com" = {
    addSSL = true;
    enableACME = true;
    root = "/var/www/static";
    
    extraConfig = ''
      # Enable directory browsing
      autoindex on;
      autoindex_exact_size off;  # Show human-readable file sizes
      autoindex_localtime on;    # Show local time instead of UTC
      
      autoindex_format html;
      
      # Enable range requests for video streaming
      location ~* \.(mp4|webm|ogg|avi|mov|flv|wmv|3gp|mkv)$ {
        add_header Accept-Ranges bytes;
        add_header Cache-Control "public, max-age=31536000";
      }
      
      # Cache image and other static files
      location ~* \.(jpg|jpeg|png|gif|ico|svg|webp|bmp|tiff)$ {
        add_header Cache-Control "public, max-age=31536000";
      }
      
      # Prevent access to hidden files
      location ~ /\. {
        deny all;
      }
    '';
  };
}
