# Multi-Machine System State Ansible Repository (home-setup)

Centralized multi-machine Ansible repository for maintaining and reproducing exact machine configurations across all your computers (`nano`, `dietpi`, etc.).

---

## 📁 Multi-Machine Repository Structure

Each machine has a dedicated folder at the root named after its hostname containing its own Ansible environment, package lists, roles, and dotfiles:

```text
home-setup/
├── README.md                # Multi-machine repository documentation
├── nano/                    # Machine: "Nano" (Debian 13 Workstation)
│   ├── setup_system.yml     # Main entrypoint for Nano
│   ├── ansible.cfg          # Local Ansible execution configuration
│   ├── inventory.ini        # Localhost inventory
│   ├── vars/
│   │   └── main.yml         # Curated package & application list for Nano
│   └── roles/
│       ├── system_packages/ # APT keyrings & curated packages
│       ├── flatpaks/        # Flathub remote & Flatpak apps
│       ├── services/        # Tailscale, Syncthing, Docker enablement
│       ├── user_tools/      # CLI binaries (yt-dlp, deno) into ~/.local/bin
│       └── dotfiles/        # Dotfiles, Konsole profiles & KDE Plasma configs
│           └── files/
│               ├── konsole/ # konsolerc & MyProfile.profile
│               ├── kde/     # kdeglobals, kwinrc, kglobalshortcutsrc
│               └── gemini/  # mcp_config.json (Antigravity MCP servers)
│
└── <other-machine>/         # Future machine configuration (e.g. dietpi, laptop, etc.)
    └── setup_system.yml
```

---

## 🚀 Running Setup on a Machine

To reproduce a specific machine's setup on a fresh vanilla system:

```bash
# 1. Install Ansible & Git on the target machine
sudo apt update && sudo apt install -y ansible git

# 2. Clone this repository
git clone git@github.com:arnabbiswas1510/home-setup.git ~/home-setup
cd ~/home-setup

# 3. Navigate to the machine's directory and run setup_system.yml
cd nano
ansible-playbook setup_system.yml --ask-become-pass
```

Alternatively, run directly from the root directory:
```bash
ansible-playbook nano/setup_system.yml --ask-become-pass
```

---

## 🏷️ Selective Execution via Tags

You can run individual roles on `nano` using Ansible tags:

```bash
# Only restore dotfiles & Konsole settings on Nano
ansible-playbook nano/setup_system.yml --tags dotfiles

# Only install Flatpak applications on Nano
ansible-playbook nano/setup_system.yml --tags flatpak

# Only install APT packages & third-party repos on Nano
ansible-playbook nano/setup_system.yml --tags packages --ask-become-pass
```

---

## 🔄 Maintaining & Adding New Machines via Prompts

Whenever you modify machine configurations or add a new computer to your fleet, use simple prompts with your AI assistant:

### Example Prompts:

1. **Updating Nano**:
   > *"I added `ripgrep` to `nano`. Update `nano/vars/main.yml` in my Ansible repo."*

2. **Adding a New Machine**:
   > *"Create a new machine configuration folder `dietpi/` in my Ansible repo with a minimal setup for Docker and Tailscale."*

3. **Updating Application Settings**:
   > *"I changed my Konsole profiles on `nano`. Update `nano/roles/dotfiles/files/konsole/` with my latest settings."*
