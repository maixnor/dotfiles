# Wieselburg Self-Hosted Services

This directory contains configuration for your self-hosted services running on the Wieselburg server.

## Services Configured

### 1. Nextcloud - Cloud Storage
- **URL**: https://cloud.maixnor.com
- **Purpose**: File storage, sync, and sharing (Dropbox/Google Drive alternative)
- **Default admin**: admin / ChangeThisPassword123! (change this!)
- **Features**: File sync, calendar, contacts, notes, and much more

### 2. Immich - Photo Management
- **URL**: https://photos.maixnor.com  
- **Purpose**: Photo and video management (Google Photos alternative)
- **Features**: AI-powered face recognition, automatic backup from mobile, timeline view, albums

### 3. Audiobookshelf - Podcasts & Audiobooks
- **URL**: https://podcasts.maixnor.com
- **Purpose**: Podcast and audiobook server with mobile apps
- **Features**: Podcast subscriptions, progress tracking, mobile apps available

### 4. Navidrome - Music Streaming
- **URL**: https://music.maixnor.com
- **Purpose**: Music streaming server (Spotify alternative for your music collection)
- **Features**: Subsonic-compatible, mobile apps, playlists, scrobbling

### 5. Collabora Online - Office Suite
- **URL**: https://office.maixnor.com
- **Purpose**: Online office suite (Google Docs/LibreOffice alternative)
- **Features**: Word processing, spreadsheets, presentations, real-time collaboration

### 6. AI Research Stack - Advanced AI Platform
- **AnythingLLM**: https://ai.maixnor.com - Comprehensive AI platform with document processing
- **Perplexica**: https://research.maixnor.com - AI research assistant with web search integration
- **SearXNG**: https://search.maixnor.com - Privacy-focused metasearch engine
- **Features**: 
  - Deep web research with source citations
  - Document analysis and RAG (Retrieval Augmented Generation)
  - Multiple AI model support (OpenAI, Anthropic)
  - Privacy-focused search without tracking
  - Native mobile app support through web interface

## Initial Setup Steps

### 1. Deploy the configuration - DONE
```bash
# From your dotfiles directory
sudo nixos-rebuild switch --flake .#wieselburg
```

### 2. DNS Configuration - DONE
Add these DNS records to your domain:
```
cloud.maixnor.com      A    YOUR_SERVER_IP
photos.maixnor.com     A    YOUR_SERVER_IP  
podcasts.maixnor.com   A    YOUR_SERVER_IP
music.maixnor.com      A    YOUR_SERVER_IP
office.maixnor.com     A    YOUR_SERVER_IP
ai.maixnor.com         A    YOUR_SERVER_IP
research.maixnor.com   A    YOUR_SERVER_IP
search.maixnor.com     A    YOUR_SERVER_IP
```

### 3. Content Organization

#### For Navidrome (Music):
```bash
# Upload your music to:
/var/lib/navidrome/music/
# Structure: Artist/Album/Track.mp3
```

#### For Audiobookshelf:
```bash
# Upload podcasts and audiobooks to:
/var/lib/audiobookshelf/podcasts/
/var/lib/audiobookshelf/audiobooks/
```

#### For Immich (Photos):
```bash
# Photos will be stored in:
/var/lib/immich/upload/
# Use the mobile app or web interface to upload
```

### 4. Security Notes

**IMPORTANT**: Change the default passwords and API keys!

- Nextcloud admin password: `/var/lib/nextcloud/admin-pass`
- Collabora admin: Change password in container environment
- AnythingLLM JWT secret: Update in `ai-research.nix`
- Add your OpenAI/Anthropic API keys for enhanced AI features (optional)

### 5. Mobile Apps

- **Nextcloud**: Official Nextcloud app
- **Immich**: Official Immich app  
- **Audiobookshelf**: Official Audiobookshelf app
- **Navidrome**: Any Subsonic-compatible app (Ultrasonic, DSub, Submariner)

## Monitoring and Maintenance

### Check service status:
```bash
# Check container status
sudo podman ps

# Check nginx status  
sudo systemctl status nginx

# Check logs
sudo journalctl -fu container@servicename
```

### Backup Important Data:
- `/var/lib/nextcloud/` - Nextcloud data
- `/var/lib/immich/` - Photo database and uploads
- `/var/lib/navidrome/data/` - Music database
- `/var/lib/audiobookshelf/config/` - Podcast/audiobook database

## Troubleshooting

### Service won't start:
1. Check if DNS records are configured
2. Verify containers are running: `sudo podman ps`
3. Check nginx configuration: `sudo nginx -t`
4. Review logs: `sudo journalctl -fu nginx`

### SSL Certificate issues:
1. Ensure DNS is pointing to your server
2. Check ACME logs: `sudo journalctl -fu acme-cloud.maixnor.com`
3. Manually trigger renewal: `sudo systemctl start acme-cloud.maixnor.com`

## Resource Usage

These services will use approximately:
- **RAM**: 2-4 GB total
- **Storage**: Variable based on your content
- **CPU**: Low to moderate depending on usage

Monitor with: `htop` and `df -h`
