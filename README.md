# Home Setup (`home-setup`)

Centralized, multi-machine **chezmoi** repository designed to maintain, back up, and reproduce exact operating system states, software packages, background services, CLI tools, dotfiles, desktop configurations (Konsole profiles, KDE Plasma shortcuts), and Antigravity MCP server configurations across all your computers (`nano`, `dietpi`, etc.).

---

## 📁 Repository Architecture

The repository uses **chezmoi** to manage dotfiles, CLI tools, and automated system setup scripts across multiple machines:

```text
home-setup/
├── README.md                                    # Global repository documentation & prompt workflow guide
├── .chezmoidata/
│   └── hosts.toml                               # Curated package, Flatpak, and service definitions per machine
├── run_onchange_before_00-install-packages.sh.tmpl # Automated APT repo keyring, package & Flatpak setup
├── run_onchange_after_10-setup-services.sh.tmpl   # Automated Systemd system and user service enablement
├── run_onchange_after_20-install-user-tools.sh.tmpl# Automated yt-dlp & Deno runtime installer
├── dot_bashrc                                   # Shell configuration (~/.bashrc)
├── dot_profile                                  # Login profile configuration (~/.profile)
├── dot_config/
│   ├── konsolerc                                # Konsole main settings
│   ├── kdeglobals                               # KDE Plasma theme & visual preferences
│   ├── kwinrc                                   # Window manager & tiling settings
│   ├── kglobalshortcutsrc                       # Global Plasma shortcuts
│   ├── IPTVnator/config.json                    # IPTVnator player configuration
│   ├── yt-dlp/config                            # yt-dlp global options & download templates
│   ├── qimgv/qimgv.conf                         # qimgv image viewer preferences
│   ├── spectaclerc                              # Spectacle screenshot settings
│   ├── dolphinrc                                # Dolphin file manager view properties
│   └── mimeapps.list                            # XDG default applications & associations
├── dot_gemini/
│   └── config/mcp_config.json                   # Antigravity MCP Server Config (Home Assistant integration)
└── dot_local/
    ├── share/konsole/MyProfile.profile          # Konsole custom profile definition
    └── bin/
        ├── executable_yt-autodownload           # Auto-download script for YouTube playlists
        ├── executable_clean-cache.sh            # User application cache cleanup utility
        ├── executable_libation                  # Libation launcher wrapper
        └── executable_iptvnator                # IPTVnator Wayland/X11 launcher wrapper
```

---

## 🚀 Quickstart: Reproducing a Machine

To reproduce a machine's setup on a fresh system:

```bash
# 1. Install chezmoi
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b ~/.local/bin

# 2. Initialize and apply the home-setup repository
chezmoi init --apply git@github.com:arnabbiswas1510/home-setup.git
```

If the repository is already cloned locally:
```bash
chezmoi apply --source ~/workspace/home-setup
```

---

## ⚙️ Managed Components for `nano`

- **APT Repositories & Packages**: Google Chrome, Sublime Text, Tailscale, Syncthing, `zsh`, `build-essential`, `curl`, `wget`, `git`, `lsof`, `rclone`, `snapper`, `btrfs-progs`, `wl-clipboard`, `qimgv`, `feh`, `flatpak`, `plasma-wallpapers-addons`
- **Flatpak Applications**: Logseq, Foliate, NormCap, RcloneUI, ZapZap, SMPlayer, mpv, Avidemux, Jellyfin Desktop, Falkon, Plex Desktop, Zoom
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

## 🏷️ Selective Execution & Inspection with chezmoi

You can preview changes or apply specific configuration targets using standard `chezmoi` commands:

```bash
# Preview changes before applying
chezmoi diff --source ~/workspace/home-setup

# Check status of target files vs managed files
chezmoi status --source ~/workspace/home-setup

# Re-apply configuration
chezmoi apply --source ~/workspace/home-setup
```

---

## 🔄 AI Prompt Maintenance Workflow

Keep your machine states up to date over time by giving simple prompts to your AI assistant:

### Example Prompts:

1. **Adding New Packages**:
   > *"I just installed `ripgrep` on `nano`. Add it to `[hosts.nano]` in `.chezmoidata/hosts.toml` in my `home-setup` repo."*

2. **Capturing Desktop Config Changes**:
   > *"I updated my Konsole color profile on `nano`. Update `dot_local/share/konsole/MyProfile.profile` with the latest file from `~/.local/share/konsole/`."*

3. **Adding a New Machine**:
   > *"Create a new host section `[hosts.dietpi]` in `.chezmoidata/hosts.toml` for my DietPi server managing Docker and Tailscale."*
