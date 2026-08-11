# Home Setup (`home-setup`)

Centralized, multi-machine Ansible repository designed to maintain, back up, and reproduce exact operating system states, software packages, background services, CLI tools, dotfiles, desktop configurations (Konsole profiles, KDE Plasma shortcuts), and Antigravity MCP server configurations across all your computers (`nano`, `dietpi`, etc.).

---

## 📁 Repository Architecture

Each machine has a dedicated, self-contained configuration directory at the root of the repository named after its hostname:

```text
home-setup/
├── README.md                # Global repository documentation & prompt workflow guide
├── nano/                    # Machine: "Nano" (Debian 13 Workstation)
│   ├── setup_system.yml     # Main playbook entrypoint for Nano
│   ├── ansible.cfg          # Local Ansible execution configuration
│   ├── inventory.ini        # Localhost inventory (127.0.0.1)
│   ├── vars/
│   │   └── main.yml         # Curated package & application definitions
│   └── roles/
│       ├── system_packages/ # APT keyrings (Chrome, Sublime, Tailscale, Syncthing) & core tools
│       ├── flatpaks/        # Flathub remote & Flatpak desktop applications
│       ├── services/        # Tailscale & Syncthing systemd services
│       ├── user_tools/      # User CLI binaries (yt-dlp, deno) into ~/.local/bin
│       └── dotfiles/        # Dotfiles, Konsole profiles, KDE shortcuts & MCP server configs
│           └── files/
│               ├── konsole/ # konsolerc & MyProfile.profile
│               ├── kde/     # kdeglobals, kwinrc, kglobalshortcutsrc
│               └── gemini/  # mcp_config.json (Home Assistant MCP server & credentials)
│
└── <other-machine>/         # Parallel roots for other systems (e.g. dietpi, laptop, etc.)
    └── setup_system.yml
```

---

## 🚀 Quickstart: Reproducing a Machine

To reproduce a machine's setup on a vanilla system:

```bash
# 1. Install Ansible & Git on the fresh system
sudo apt update && sudo apt install -y ansible git

# 2. Clone this repository
git clone git@github.com:arnabbiswas1510/home-setup.git ~/home-setup
cd ~/home-setup

# 3. Run setup for your target machine (e.g., nano)
cd nano
ansible-playbook setup_system.yml --ask-become-pass
```

Alternatively, run from the root directory:
```bash
ansible-playbook nano/setup_system.yml --ask-become-pass
```

---

## ⚙️ Managed Components for `nano`

- **APT Repositories & Packages**: Google Chrome, Sublime Text, Tailscale, Syncthing, `zsh`, `build-essential`, `curl`, `wget`, `git`, `lsof`, `rclone`, `snapper`, `btrfs-progs`, `wl-clipboard`, `qimgv`, `feh`, `flatpak`, `plasma-wallpapers-addons`
- **Flatpak Applications**: Logseq, Foliate, NormCap, Rclone UI, ZapZap, SMPlayer, mpv, Avidemux, Jellyfin Desktop, Falkon, Plex Desktop, Zoom
- **CLI Tools & Custom Scripts**: `yt-dlp`, `deno`, `yt-autodownload`, `clean-cache.sh`, `libation` wrapper, `iptvnator` launcher deployed to `~/.local/bin`
- **Desktop & Application Preferences**:
  - Konsole Settings & Custom Profiles (`konsolerc`, `MyProfile.profile`)
  - KDE Plasma Preferences & Shortcuts (`kdeglobals`, `kwinrc`, `kglobalshortcutsrc`)
  - Spectacle Screenshot Config (`spectaclerc`) & Dolphin Settings (`dolphinrc`)
  - IPTVnator Main Configuration (`~/.config/IPTVnator/config.json`)
  - Media & Application Preferences (`yt-dlp/config`, `qimgv.conf`, `mimeapps.list`)
- **AI & MCP Server Integrations**:
  - Antigravity MCP Server Config (`~/.gemini/config/mcp_config.json`) including Home Assistant integration

---

## 🏷️ Selective Execution via Ansible Tags

You can execute specific roles independently using Ansible tags:

```bash
# Restore only dotfiles, Konsole profiles & MCP configs on Nano
ansible-playbook nano/setup_system.yml --tags dotfiles

# Install only Flatpak applications
ansible-playbook nano/setup_system.yml --tags flatpak

# Install APT packages & third-party repos (Chrome, Sublime, Tailscale)
ansible-playbook nano/setup_system.yml --tags packages --ask-become-pass
```

---

## 🔄 AI Prompt Maintenance Workflow

Keep your machine states up to date over time by giving simple prompts to your AI assistant:

### Example Prompts:

1. **Adding New Packages**:
   > *"I just installed `ripgrep` on `nano`. Add it to `nano/vars/main.yml` in my `home-setup` repo."*

2. **Capturing Desktop Config Changes**:
   > *"I updated my Konsole color profile on `nano`. Update `nano/roles/dotfiles/files/konsole/` with the latest files from `~/.local/share/konsole/`."*

3. **Adding a New Machine**:
   > *"Create a new machine folder `dietpi/` in `home-setup` for my DietPi server managing Docker and Tailscale."*
