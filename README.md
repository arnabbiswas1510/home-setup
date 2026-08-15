# Home Setup (`home-setup`)

Centralized multi-machine repository managing operating system configurations, dotfiles, hardware fixes, background services, Docker infrastructure, and AI tool integrations across all home systems.

---

## 💻 Machines Overview

| Folder | Machine Name | OS / Hardware | Role & Architecture |
| :--- | :--- | :--- | :--- |
| **[`nano/`](./nano/)** | `Nano` | Debian 13 (Trixie) / Lenovo ThinkPad X1 Nano Gen 3 | Primary Workstation: KDE Plasma (Wayland), DisplayLink Hybrid Dock fixes, chezmoi dotfiles, Flatpaks, Antigravity MCP servers |
| **[`dietpi/`](./dietpi/)** | `DietPi` | DietPi (Debian) / Headless Server (`192.168.1.50`) | Central NAS & Application Server: 30+ Docker containers, Samba network storage, Gitwatch continuous sync, rsync backups |

---

## 📁 Repository Structure

```text
home-setup/
├── README.md                                    # Global multi-machine overview
├── .gitignore                                   # Git ignore rules
├── nano/                                        # ThinkPad X1 Nano workstation configuration
│   ├── README.md                                # Machine-specific documentation & runbook
│   ├── .chezmoidata/
│   │   └── hosts.toml                           # Host package and service definitions
│   ├── run_onchange_before_00-install-packages.sh.tmpl # Automated APT & Flatpak installer
│   ├── run_onchange_after_10-setup-services.sh.tmpl   # Automated Systemd services setup
│   ├── run_onchange_after_20-install-user-tools.sh.tmpl# yt-dlp & Deno tool installer
│   ├── dot_bashrc                               # Shell configuration (~/.bashrc)
│   ├── dot_profile                              # Login profile (~/.profile)
│   ├── dot_config/                              # Konsole, KDE Plasma, IPTVnator, yt-dlp, qimgv, etc.
│   ├── dot_gemini/                              # Antigravity MCP servers (Home Assistant, Garmin)
│   ├── dot_local/                               # Custom launcher wrappers & Konsole profiles
│   ├── os-tweaks/                               # Hardware fixes (DisplayLink EVDI, dock unfreeze, fastboot)
│   └── scripts/                                 # Helper installers (Oh My Zsh, Plex, Syncthing)
└── dietpi/                                      # DietPi server & NAS infrastructure
    ├── README.md                                # Server documentation & container port map
    ├── dot_bashrc                               # Server shell environment (~/.bashrc)
    ├── dot_profile                              # Server login profile (~/.profile)
    ├── dot_gitconfig                            # Server git configuration (~/.gitconfig)
    ├── bin/                                     # Server scripts (run-all-rsync.sh)
    ├── gitwatch/                                # Inotify auto-commit & push service template
    ├── os-tweaks/                               # System setup, Samba share exports, cron automation
    └── docker/                                  # Multi-service Docker Compose stacks
        ├── docker-compose.yml                   # Unified media, download, monitoring stack
        ├── .env.example                         # Environment variable template
        ├── dawarich/                            # Self-hosted geolocation tracking
        ├── omnivore/                            # Read-it-later article archive
        ├── tdarr/                               # Distributed media transcoding
        ├── opencode/                            # OpenCode AI server
        ├── logseq-db/                           # Logseq DB sync engine
        ├── logseq_sync_server/                  # Logseq Cognito sync server
        ├── ai-trading-bot/                      # Interactive Brokers & CAN SLIM bot stack
        └── garmin-ai-coach/                     # AI Health & Endurance Coach
```

---

## 🚀 Quickstarts

### Reproducing `Nano` Workstation

```bash
# 1. Install chezmoi if not already installed
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b ~/.local/bin

# 2. Apply configuration from the nano directory
chezmoi apply --source ~/workspace/home-setup/nano

# 3. Apply hardware & OS tweaks (DisplayLink dock, boot speed, NAS mounts)
cd ~/workspace/home-setup/nano/os-tweaks
sudo ./apply_evdi_wayland_fix.sh
sudo ./fix_dock_unplug.sh
sudo ./optimize_boot.sh
sudo ./setup_nas_mounts.sh
```

### Reproducing `DietPi` Server & NAS

```bash
# 1. Clone repository
git clone git@github.com:arnabbiswas1510/home-setup.git ~/workspace/home-setup
cd ~/workspace/home-setup/dietpi

# 2. Run system setup & Samba share configuration
sudo ./os-tweaks/setup_system.sh
sudo ./os-tweaks/setup_samba_shares.sh

# 3. Set up Gitwatch & rsync backups
sudo ./os-tweaks/setup_gitwatch.sh
./os-tweaks/setup_rsync_cron.sh

# 4. Launch Docker services
cd docker
cp .env.example .env
nano .env
docker compose up -d
```

---

## 🔄 Maintenance & Prompt Workflow

To maintain machine states over time using your AI pair programmer:

- **Adding a Package on Nano**:
  > *"I installed `htop` on Nano. Add it to `nano/.chezmoidata/hosts.toml` in my `home-setup` repo."*
- **Updating Docker Compose on DietPi**:
  > *"I updated the Jellyfin image on DietPi. Update `dietpi/docker/docker-compose.yml` in my `home-setup` repo."*
- **Updating Dotfiles**:
  > *"Sync my latest Konsole shortcuts from `~/.config/kglobalshortcutsrc` into `nano/dot_config/kglobalshortcutsrc`."*
