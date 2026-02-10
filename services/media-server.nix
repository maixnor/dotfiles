{ pkgs, lib, config, ... }:

let
  cfg = config.services.traefik;
  downloadDir = "/var/www/static";
  webhookPort = 9002;
in
{
  # Enable Jellyfin media server
  services.jellyfin = {
    enable = true;
    openFirewall = false; # Handled by Traefik
  };

  # Add jellyfin to web-static group to read downloaded videos
  users.users.jellyfin.extraGroups = [ "web-static" ];

  # YouTube cookies secret from agenix
  age.secrets."youtube-cookies" = {
    file = ../secrets/youtube-cookies.txt.age;
    mode = "0444";
  };

  # Webhook listener for downloads
  systemd.services.webhook-downloader = {
    description = "Webhook listener for YouTube downloads";
    wantedBy = [ "multi-user.target" ];
    path = with pkgs; [ webhook yt-dlp ffmpeg coreutils bash ];
    serviceConfig = {
      ExecStart = "${pkgs.webhook}/bin/webhook -hooks ${pkgs.writeText "download-hooks.json" (builtins.toJSON [
        {
          id = "download";
          execute-command = "${pkgs.writeShellScript "download-video.sh" ''
            set -euo pipefail
            URL=$1
            echo "Downloading $URL to ${downloadDir}"
            ${pkgs.yt-dlp}/bin/yt-dlp \
              --cookies "${config.age.secrets."youtube-cookies".path}" \
              --impersonate chrome \
              --extractor-args "youtube:player-client=android,ios" \
              -f "bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best" \
              -o "${downloadDir}/%(playlist_title&{} - |)s%(playlist_index&{} - |)s%(title)s.%(ext)s" \
              "$URL"
            chmod 664 "${downloadDir}"/*
          ''}";
          pass-arguments-to-command = [
            { source = "payload"; name = "url"; }
          ];
          response-message = "Download started";
        }
      ])} -port ${toString webhookPort} -verbose";
      User = "web-static";
      WorkingDirectory = downloadDir;
    };
  };

  # Dedicated service for the downloader UI
  systemd.services.downloader-ui = {
    description = "Downloader UI server";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.python3}/bin/python -m http.server 6780";
      WorkingDirectory = pkgs.linkFarm "downloader-ui" [
        { name = "index.html"; path = pkgs.writeText "downloader.html" ''
          <!DOCTYPE html>
          <html lang="en">
          <head>
              <meta charset="UTF-8">
              <meta name="viewport" content="width=device-width, initial-scale=1.0">
              <title>Maya Downloader</title>
              <style>
                  body { font-family: sans-serif; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; background: #121212; color: white; }
                  .container { background: #1e1e1e; padding: 2rem; border-radius: 8px; box-shadow: 0 4px 6px rgba(0,0,0,0.3); width: 100%; max-width: 400px; }
                  h1 { margin-top: 0; color: #00a4dc; }
                  input { width: 100%; padding: 10px; margin: 10px 0; border: 1px solid #333; border-radius: 4px; background: #2c2c2c; color: white; box-sizing: border-box; }
                  button { width: 100%; padding: 10px; background: #00a4dc; border: none; border-radius: 4px; color: white; font-weight: bold; cursor: pointer; }
                  button:hover { background: #0085b2; }
                  #status { margin-top: 15px; font-size: 0.9rem; }
              </style>
          </head>
          <body>
              <div class="container">
                  <h1>Maya Downloader</h1>
                  <p>Paste a YouTube URL to download it to Jellyfin.</p>
                  <input type="text" id="url" placeholder="https://www.youtube.com/watch?v=...">
                  <button onclick="download()">Download</button>
                  <div id="status"></div>
              </div>
              <script>
                  async function download() {
                      const url = document.getElementById('url').value;
                      const status = document.getElementById('status');
                      if (!url) return;
                      
                      status.innerText = "Sending request...";
                      try {
                          const response = await fetch('/hooks/download', {
                              method: 'POST',
                              headers: { 'Content-Type': 'application/json' },
                              body: JSON.stringify({ url: url })
                          });
                          if (response.ok) {
                              status.innerText = "Download triggered successfully!";
                              document.getElementById('url').value = "";
                          } else {
                              status.innerText = "Error: " + await response.text();
                          }
                      } catch (e) {
                          status.innerText = "Error: " + e.message;
                      }
                  }
              </script>
          </body>
          </html>
        ''; }
      ];
      User = "web-static";
      Group = "web-static";
    };
  };

  # Traefik configuration for media.maixnor.com
  environment.etc."traefik/media.yml" = lib.mkIf cfg.enable {
    text = ''
      http:
        routers:
          jellyfin:
            rule: "Host(`media.maixnor.com`) && !PathPrefix(`/downloader`) && !PathPrefix(`/hooks`)"
            service: "jellyfin"
            entryPoints:
              - "websecure"
            tls:
              certResolver: "letsencrypt"
          
          downloader-ui:
            rule: "Host(`media.maixnor.com`) && PathPrefix(`/downloader`)"
            service: "downloader-ui"
            middlewares:
              - "downloader-strip-prefix"
            entryPoints:
              - "websecure"
            tls:
              certResolver: "letsencrypt"

          downloader-webhook:
            rule: "Host(`media.maixnor.com`) && PathPrefix(`/hooks/download`)"
            service: "downloader-webhook"
            entryPoints:
              - "websecure"
            tls:
              certResolver: "letsencrypt"

        middlewares:
          downloader-strip-prefix:
            stripPrefix:
              prefixes:
                - "/downloader"

        services:
          jellyfin:
            loadBalancer:
              servers:
                - url: "http://127.0.0.1:8096"
          
          downloader-ui:
            loadBalancer:
              servers:
                - url: "http://127.0.0.1:6780"
          
          downloader-webhook:
            loadBalancer:
              servers:
                - url: "http://127.0.0.1:${toString webhookPort}"
    '';
  };
}
