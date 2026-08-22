# DietPi Server Setup (`dietpi`)

Configuration, dotfiles, Docker stack definitions, Samba shares, backup scripts, and automation for the **DietPi Headless Server & NAS** (`192.168.1.50`).

---

## 📁 Folder Structure

```text
dietpi/
├── README.md                                    # Server documentation & service port map
├── dot_bashrc                                   # Shell environment (~/.bashrc)
├── dot_profile                                  # User profile (~/.profile)
├── dot_gitconfig                                # Git global configuration (~/.gitconfig)
├── bin/
│   └── run-all-rsync.sh                         # Automated scratch-to-photos rsync routine
├── gitwatch/
│   ├── gitwatch.sh                              # Inotify-based Git auto-commit & push script
│   └── gitwatch@.service                        # Systemd unit template for watching git directories
├── os-tweaks/
│   ├── setup_system.sh                          # Base packages, Docker CE, Tailscale, agy, & storage dirs
│   ├── setup_samba_shares.sh                    # smb.conf setup for media & home shares
│   ├── setup_gitwatch.sh                        # Installs gitwatch to /usr/local/bin & systemd
│   ├── setup_rsync_cron.sh                      # Crontab schedule for run-all-rsync.sh
│   ├── install_agy.sh                           # Standalone Antigravity CLI (agy) installer
│   └── install_ohmyzsh.sh                       # Zsh & Oh My Zsh installer
└── docker/
    ├── docker-compose.yml                       # Unified multi-service Docker Compose stack
    ├── .env.example                             # Environment variable template for secrets & paths
    ├── config/
    │   └── dufs/config.yaml                     # Dufs file server configuration
    ├── dawarich/
    │   ├── docker-compose.yml                   # Self-hosted geolocation tracking service
    │   └── .env.example                         # Dawarich configuration template
    ├── omnivore/
    │   └── docker-compose.yml                   # Read-it-later self-hosted stack
    ├── tdarr/
    │   └── docker-compose.yml                   # Audio/video distributed transcoding node
    ├── opencode/
    │   └── Dockerfile                           # OpenCode AI server container build
    ├── logseq-db/
    │   ├── docker-compose.yml                   # Logseq DB sync server
    │   ├── Dockerfile                           # Logseq DB build definition
    │   └── mise.toml                            # Mise runtime configuration
    ├── logseq_sync_server/
    │   ├── docker-compose.yml                   # Logseq sync server with Cognito auth
    │   └── .env.example                         # Logseq sync server environment template
    ├── ai-trading-bot/
    │   ├── docker-compose.yml                   # IB Gateway & CAN SLIM trading bot stack
    │   └── .env.example                         # Trading bot environment variables template
    └── garmin-ai-coach/
        ├── docker-compose.yml                   # Garmin AI health coach background poller & API
        ├── coach_config.yaml                    # Athlete profile & goal parameters
        └── .env.example                         # Coach environment variables template
```

---

## 🚀 Quickstart: Initial Provisioning

To set up a fresh DietPi server:

```bash
# 1. Clone repository
git clone git@github.com:arnabbiswas1510/home-setup.git ~/workspace/home-setup
cd ~/workspace/home-setup/dietpi

# 2. Run system setup (installs Docker, Tailscale, Samba, rsync, Antigravity CLI)
sudo ./os-tweaks/setup_system.sh

# 3. Configure Samba shares (exports /mnt/media1, /mnt/media2, /mnt/books, etc.)
sudo ./os-tweaks/setup_samba_shares.sh
sudo smbpasswd -a dietpi

# 4. Set up Gitwatch (for automated Obsidian vault backup)
sudo ./os-tweaks/setup_gitwatch.sh
sudo systemctl enable --now gitwatch@$(systemd-escape /home/dietpi/obsidian).service

# 5. Set up scheduled Rsync sync
./os-tweaks/setup_rsync_cron.sh
```

---

## 🐳 Docker Services & Port Map

| Service | Port | Description |
| :--- | :--- | :--- |
| **Immich Web / API** | `2283` | High-performance self-hosted photo & video backup |
| **Plex Media Server** | `32400` (host) | Media server with hardware transcoding |
| **Audiobookshelf** | `13378` | Audiobook & podcast streaming server |
| **Komga** | `25600` | Comic & eBook reader server |
| **Kavita** | `6060` | Digital library & manga reader |
| **Code Server** | `8443` | Web-based VS Code environment with Python / Node |
| **OpenCode AI** | `4096` | Local AI development assistant |
| **Obsidian WebDAV** | `8082` | WebDAV endpoint for Obsidian mobile vault sync |
| **Dufs** | `5000` | Lightweight static web file server & browser |
| **Gluetun VPN** | N/A | NordVPN OpenVPN network container for Arr suite |
| **qBittorrent** | `8888` (via VPN) | Torrent client with Web UI |
| **SABnzbd** | `8181` (via VPN) | Usenet downloader |
| **Sonarr** | `8989` (via VPN) | TV series management |
| **Radarr** | `7878` (via VPN) | Movie collection manager |
| **Prowlarr** | `9696` (via VPN) | Indexer manager & proxy |
| **Lidarr** | `8686` (via VPN) | Music collection manager |
| **Bazarr** | `6767` (via VPN) | Subtitle manager |
| **Whisparr** | `6969` (via VPN) | Media collection manager |
| **n8n** | `5678` | Workflow automation tool |
| **Dozzle** | `8080` | Real-time Docker container log viewer |
| **IT-Tools** | `8998` | Collection of handy online developer tools |
| **IB Gateway (Debug)** | `4002` / `5900` | Interactive Brokers API & VNC interface |
| **NetAlertX** | `20211` / `20212` | Network intruder detector & ARP scanner |
| **ntopng** | `3000` (host) | High-speed web-based traffic monitoring |
| **Emby Server** | `8096` | Alternative media server |
| **Jellyfin** | `8097` | Open-source media system with Meilisearch |
| **Meilisearch** | `7700` | Lightning fast search engine for Jellyfin |
| **Stash** | `9999` | Adult media management server with scrapers & AI tagging |
| **Adminer** | `8090` | Database management tool |
| **Dawarich** | `3020` | Geolocation tracking server & maps |
| **Omnivore Web / API**| `3010` / `4000` | Read-it-later article bookmarking |
| **Tdarr Web UI** | `8265` | Audio/video transcoding node & coordinator |
| **Logseq Sync Server**| `8790` | Self-hosted Logseq database sync |
| **AI Trading Bot** | `8000` | Automated CAN SLIM trading execution system |
| **Garmin AI Coach** | `8085` / `8001` | Garmin metrics analyzer & training dashboard |

---

## 🔐 Starting Docker Services

```bash
cd ~/workspace/home-setup/dietpi/docker

# 1. Copy environment template and fill in required API tokens
cp .env.example .env
nano .env

# 2. Launch all core containers in detached mode
docker compose up -d

# 3. Launch specific profiles (e.g. trading and health)
docker compose --profile trading --profile health up -d
```
