#!/usr/bin/env bash
# NixOS Configuration Setup Script
# This script sets up your dotfiles workflow with Home Manager
set -e # Exit on any error

echo "🚀 Setting up NixOS configuration management..."

# Function to check if Home Manager is available
check_home_manager() {
  if ! nix-instantiate --eval -E '<home-manager>' >/dev/null 2>&1; then
    return 1
  fi
  return 0
}

# Function to install Home Manager
install_home_manager() {
  echo "📦 Home Manager not found. Installing..."

  # Add home-manager channel
  sudo nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager
  sudo nix-channel --update

  echo "✅ Home Manager channel added. Updating channels..."

  # Verify installation
  if check_home_manager; then
    echo "✅ Home Manager is now available!"
    return 0
  else
    echo "❌ Failed to install Home Manager via channels."
    echo "🔧 Trying alternative method..."
    return 1
  fi
}

# Function to create fallback configuration without Home Manager
create_fallback_config() {
  echo "🔄 Creating configuration without Home Manager integration..."

  cat >c.nix <<'EOF'
# Edit this file in ~/wlmrNix/c.nix
# Run 'sudo nixos-rebuild switch' after changes
{ config, pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
  ];

  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Network
  networking.hostName = "wlmr-machine";
  networking.networkmanager.enable = true;

  # Users
  users.users.wlmr = {
    isNormalUser = true;
    description = "wlmr";
    extraGroups = [ "networkmanager" "wheel" ];
    shell = pkgs.fish;
  };

  # Enable essential programs
  programs.fish.enable = true;
  programs.hyprland.enable = true;

  nixpkgs.config.allowUnfree = true;

  # System packages (includes user essentials)
  environment.systemPackages = with pkgs; [
    # Core system
    git
    curl
    wget
    neovim
    
    # Terminal and shell
    alacritty
    fish
    starship
    eza
    bat
    ripgrep
    fd
    fzf
    zoxide
    
    # Wayland/Hyprland essentials
    waybar
    fuzzel
    mako
    grim
    slurp
    wl-clipboard
    hyprpaper
    
    # GUI applications
    firefox
    mpv
    imv
    pavucontrol
    
    # Development
    rustc
    cargo
    rust-analyzer
    nodejs
    python3
    
    # Productivity
    obsidian
    anki-bin
    btop
  ];

  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-cjk-sans
    nerd-fonts.jetbrains.mono
  ];

  # XDG Portal for Hyprland
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-hyprland ];
  };

  # Audio
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Enable flakes (optional)
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  
  system.stateVersion = "25.11";
}
EOF

  # Create a simple user config reminder
  cat >h.nix <<'EOF'
# This file is not being used in the current configuration
# Home Manager is not set up. User configs are in c.nix under environment.systemPackages
# 
# To enable Home Manager later:
# 1. Make sure Home Manager is installed: sudo nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager
# 2. Update channels: sudo nix-channel --update
# 3. Re-run this setup script
#
# For now, edit c.nix to add packages and configurations.
{ config, pkgs, ... }:
{
}
EOF

  echo "⚠️  Created fallback configuration without Home Manager."
  echo "📝 All packages are now defined in c.nix under environment.systemPackages"
  echo "🔧 To enable Home Manager later, run: sudo nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager && sudo nix-channel --update"
}

# Function to create full Home Manager configuration
create_home_manager_config() {
  cat >c.nix <<'EOF'
# Edit this file in ~/wlmrNix/c.nix
# Run 'sudo nixos-rebuild switch' after changes
{ config, pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    <home-manager/nixos>
  ];

  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Network
  networking.hostName = "wlmr-machine";
  networking.networkmanager.enable = true;

  # Users
  users.users.wlmr = {
    isNormalUser = true;
    description = "wlmr";
    extraGroups = [ "networkmanager" "wheel" ];
  };

  # Enable programs needed for Wayland/Hyprland
  programs.hyprland.enable = true;

  # XDG Portal for Hyprland
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-hyprland ];
  };

  # Audio
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  nixpkgs.config.allowUnfree = true;

  # System packages (minimal - most stuff in Home Manager)
  environment.systemPackages = with pkgs; [
    git
    curl
    wget
    neovim
  ];

  # Home Manager
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.wlmr = import ./h.nix;
    backupFileExtension = "bak";
    stateVersion = "25.05";
  };

  # Enable flakes (optional)
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  
  system.stateVersion = "25.11";
}
EOF
}

# Create your config directory
mkdir -p ~/wlmrNix
cd ~/wlmrNix

# Initialize git repo if not already done
if [ ! -d ".git" ]; then
  git init
  echo "# WlmrNix - Personal NixOS Configuration" >README.md
  echo "My personalized NixOS setup with Home Manager" >>README.md
fi

# Check if Home Manager is available and handle accordingly
if check_home_manager; then
  echo "✅ Home Manager found! Creating full configuration..."
  create_home_manager_config
else
  echo "⚠️  Home Manager not found in NIX_PATH"
  read -p "🔧 Would you like to install Home Manager? (y/N): " -n 1 -r
  echo

  if [[ $REPLY =~ ^[Yy]$ ]]; then
    if install_home_manager; then
      echo "✅ Home Manager installed successfully!"
      create_home_manager_config
    else
      echo "❌ Failed to install Home Manager. Using fallback configuration."
      create_fallback_config
    fi
  else
    echo "📝 Skipping Home Manager installation. Using fallback configuration."
    create_fallback_config
  fi
fi

# Create modular config structure
mkdir -p ~/wlmrNix/modules

# Create main home.nix (only if Home Manager is available)
if check_home_manager; then
  cat >h.nix <<'EOF'
# Main Home Manager configuration
# This imports all your modular configurations
{ config, pkgs, ... }:
  {
  home.username = "wlmr";
  home.homeDirectory = "/home/wlmr";

  # Import all your modular configurations with absolute paths
  imports = [
    /home/wlmr/wlmrNix/modules/hyprland.nix
    /home/wlmr/wlmrNix/modules/terminal.nix
    /home/wlmr/wlmrNix/modules/apps.nix
    /home/wlmr/wlmrNix/modules/theme.nix
    /home/wlmr/wlmrNix/modules/development.nix
    /home/wlmr/wlmrNix/modules/productivity.nix
  ];

  # Basic packages that don't need special config
  home.packages = with pkgs; [
    # System utilities
    btop
    neofetch
    tree
    unzip
    p7zip
    curl
    wget
  ];

  # Git configuration (core identity)
  programs.git = {
    enable = true;
    userName = "wlmr";
    userEmail = "your-email@example.com";
  };
}
EOF
fi

# Create Hyprland configuration module
cat >modules/hyprland.nix <<'EOF'
# Hyprland and window manager setup
{ config, pkgs, ... }:
{
  # Hyprland window manager
  wayland.windowManager.hyprland = {
    enable = true;
    settings = {
      # Monitors - adjust for your display
      monitor = [
        ",preferred,auto,auto"
      ];
      
      # Startup applications
      exec-once = [
        "waybar"
        "mako"
        "hyprpaper"
      ];
      
      # Key bindings
      bind = [
        "SUPER, RETURN, exec, alacritty"
        "SUPER, Q, killactive"
        "SUPER, M, exit"
        "SUPER, E, exec, nautilus"
        "SUPER, V, togglefloating"
        "SUPER, R, exec, fuzzel"
        "SUPER, P, pseudo"
        "SUPER, J, togglesplit"
        
        # Screenshots
        ", Print, exec, grim -g \"$(slurp)\" - | wl-copy"
        "SHIFT, Print, exec, grim -g \"$(slurp)\" ~/Pictures/screenshot_$(date +%Y%m%d_%H%M%S).png"
        
        # Movement
        "SUPER, H, movefocus, l"
        "SUPER, L, movefocus, r"
        "SUPER, K, movefocus, u"
        "SUPER, J, movefocus, d"
        
        # Workspaces
        "SUPER, 1, workspace, 1"
        "SUPER, 2, workspace, 2"
        "SUPER, 3, workspace, 3"
        "SUPER, 4, workspace, 4"
        "SUPER, 5, workspace, 5"
        
        # Move windows to workspaces
        "SUPER SHIFT, 1, movetoworkspace, 1"
        "SUPER SHIFT, 2, movetoworkspace, 2"
        "SUPER SHIFT, 3, movetoworkspace, 3"
        "SUPER SHIFT, 4, movetoworkspace, 4"
        "SUPER SHIFT, 5, movetoworkspace, 5"
      ];
      
      # Window rules for productivity
      windowrulev2 = [
        "float,class:^(Anki)$"
        "size 1200 800,class:^(Anki)$"
        "center,class:^(Anki)$"
      ];
    };
  };

  # Waybar configuration
  programs.waybar = {
    enable = true;
    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        height = 35;
        
        modules-left = [ "hyprland/workspaces" "hyprland/window" ];
        modules-center = [ "clock" ];
        modules-right = [ "pulseaudio" "network" "battery" "tray" ];
        
        "hyprland/workspaces" = {
          disable-scroll = true;
          all-outputs = true;
          format = "{icon}";
          format-icons = {
            "1" = "󰈹";
            "2" = "";
            "3" = "";
            "4" = "󰎆";
            "5" = "󰍳";
            default = "";
          };
        };
        
        clock = {
          format = "{:%H:%M}";
          format-alt = "{:%A, %B %d, %Y (%R)}";
          tooltip-format = "<tt><small>{calendar}</small></tt>";
        };
        
        battery = {
          format = "{capacity}% {icon}";
          format-icons = ["" "" "" "" ""];
        };
        
        network = {
          format-wifi = "{essid} ";
          format-ethernet = "Connected ";
          format-disconnected = "Disconnected ⚠";
        };
        
        pulseaudio = {
          format = "{volume}% {icon}";
          format-muted = "🔇";
          format-icons = {
            default = ["🔈" "🔉" "🔊"];
          };
        };
      };
    };
    
    style = ''
      * {
        font-family: "JetBrains Mono Nerd Font";
        font-size: 13px;
        border: none;
        border-radius: 0;
        min-height: 0;
      }
      
      window#waybar {
        background: rgba(26, 27, 38, 0.9);
        color: #c0caf5;
        border-bottom: 2px solid #7aa2f7;
      }
      
      #workspaces button {
        padding: 0 10px;
        color: #565f89;
      }
      
      #workspaces button.active {
        color: #7aa2f7;
        background: rgba(122, 162, 247, 0.2);
      }
    '';
  };

  # Screenshot utilities
  home.packages = with pkgs; [
    grim
    slurp
    wl-clipboard
  ];
}
EOF

# Create remaining module files
cat >modules/terminal.nix <<'EOF'
# Terminal and shell configuration
{ config, pkgs, ... }:
{
  # Fish shell configuration
  programs.fish = {
    enable = true;
    shellAliases = {
      ll = "eza -la";
      la = "eza -la";
      ls = "eza";
      cat = "bat";
      find = "fd";
      grep = "rg";
    };
  };

  # Alacritty terminal
  programs.alacritty = {
    enable = true;
    settings = {
      window = {
        padding = { x = 10; y = 10; };
        opacity = 0.95;
      };
      font = {
        normal = { family = "JetBrains Mono Nerd Font"; };
        size = 12;
      };
      colors = {
        primary = {
          background = "0x1a1b26";
          foreground = "0xc0caf5";
        };
      };
    };
  };

  # Starship prompt
  programs.starship = {
    enable = true;
    settings = {
      format = "$directory$git_branch$git_status$character";
      character = {
        success_symbol = "[➜](bold green)";
        error_symbol = "[➜](bold red)";
      };
    };
  };

  # Essential CLI tools
  home.packages = with pkgs; [
    eza
    bat
    ripgrep
    fd
    fzf
    zoxide
  ];
}
EOF

cat >modules/apps.nix <<'EOF'
# GUI Applications
{ config, pkgs, ... }:
{
  home.packages = with pkgs; [
    # Web browser
    firefox
    
    # File manager
    nautilus
    
    # Media
    mpv
    imv
    
    # Audio control
    pavucontrol
    
    # Launcher
    fuzzel
  ];

  # Fuzzel launcher configuration
  programs.fuzzel = {
    enable = true;
    settings = {
      main = {
        font = "JetBrains Mono Nerd Font:size=12";
        terminal = "alacritty";
      };
      colors = {
        background = "1a1b26dd";
        text = "c0caf5ff";
        selection = "7aa2f7ff";
        selection-text = "1a1b26ff";
      };
    };
  };
}
EOF

cat >modules/theme.nix <<'EOF'
# Theme and appearance configuration
{ config, pkgs, ... }:
{
  # Notification daemon
  services.mako = {
    enable = true;
    backgroundColor = "#1a1b26";
    textColor = "#c0caf5";
    borderColor = "#7aa2f7";
    borderRadius = 8;
    font = "JetBrains Mono Nerd Font 11";
  };

  # GTK theme
  gtk = {
    enable = true;
    theme = {
      package = pkgs.tokyo-night-gtk;
      name = "Tokyonight-Dark-B";
    };
  };
}
EOF

cat >modules/development.nix <<'EOF'
# Development tools and environments
{ config, pkgs, ... }:
{
  home.packages = with pkgs; [
    # Rust development
    rustc
    cargo
    rust-analyzer
    
    # Web development
    nodejs
    
    # Python
    python3
    
    # Version control
    git
    
    # Editor
    neovim
  ];

  # Git configuration is in main h.nix file
  # Add more development-specific configs here
}
EOF

cat >modules/productivity.nix <<'EOF'
# Productivity and learning applications
{ config, pkgs, ... }:
{
  home.packages = with pkgs; [
    # Knowledge management
    obsidian
    
    # Flashcards for learning
    anki-bin
    
    # System monitoring
    btop
    
    # Utilities
    tree
    unzip
    p7zip
  ];
}
EOF

# Create enhanced sync script with proper error handling
cat >sync.sh <<'EOF'
#!/usr/bin/env bash
# Enhanced sync script for sigma productivity workflow
# Usage: ./sync.sh [--force] [--silent] [--check]

set -e

FORCE=false
SILENT=false
CHECK_ONLY=false

# Parse arguments
for arg in "$@"; do
    case $arg in
        --force)
            FORCE=true
            shift
            ;;
        --silent)
            SILENT=true
            shift
            ;;
        --check)
            CHECK_ONLY=true
            shift
            ;;
    esac
done

# Function to check configuration syntax
check_config() {
    if [[ $SILENT == false ]]; then
        echo "🔍 Checking configuration syntax..."
    fi
    
    # Check if Home Manager is being used but not available
    if grep -q "home-manager/nixos" ~/wlmrNix/c.nix; then
        if ! nix-instantiate --eval -E '<home-manager>' >/dev/null 2>&1; then
            echo "❌ Error: Configuration uses Home Manager but it's not installed!"
            echo "🔧 Run: sudo nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager"
            echo "🔧 Then: sudo nix-channel --update"
            return 1
        fi
    fi
    
    # Check if configuration file exists
    if [ ! -f ~/wlmrNix/c.nix ]; then
        echo "❌ Configuration file c.nix not found!"
        return 1
    fi
    
    # Try to parse the configuration
    if ! sudo nix-instantiate /etc/nixos/configuration.nix --eval --strict -A config.system.build.toplevel >/dev/null 2>&1; then
        echo "❌ Configuration syntax error detected!"
        echo "🔧 Check your configuration files for syntax errors"
        return 1
    fi
    
    if [[ $SILENT == false ]]; then
        echo "✅ Configuration syntax is valid!"
    fi
    return 0
}

if [[ $SILENT == false ]]; then
    echo "🚀 [$(date '+%H:%M:%S')] Syncing NixOS configuration..."
fi

# Ensure we're in the right directory
if [ ! -d ~/wlmrNix ]; then
    echo "❌ ~/wlmrNix directory not found! Run the setup script first."
    exit 1
fi

cd ~/wlmrNix

# Copy hardware config if it doesn't exist in our repo
if [ ! -f ~/wlmrNix/hardware-configuration.nix ]; then
    if [ -f /etc/nixos/hardware-configuration.nix ]; then
        cp /etc/nixos/hardware-configuration.nix ~/wlmrNix/
        [[ $SILENT == false ]] && echo "✅ Copied hardware-configuration.nix"
    else
        echo "⚠️  Warning: No hardware-configuration.nix found in /etc/nixos/"
        echo "🔧 You may need to generate it with: sudo nixos-generate-config"
    fi
fi

# Sync our configs to /etc/nixos/
sudo cp ~/wlmrNix/c.nix /etc/nixos/configuration.nix

# Only copy h.nix if it's being used
if grep -q "import ./h.nix" ~/wlmrNix/c.nix; then
    sudo cp ~/wlmrNix/h.nix /etc/nixos/
fi

if [ -f ~/wlmrNix/hardware-configuration.nix ]; then
    sudo cp ~/wlmrNix/hardware-configuration.nix /etc/nixos/
fi

[[ $SILENT == false ]] && echo "✅ Configuration files synced!"

# Check configuration before rebuilding
if ! check_config; then
    echo "❌ Configuration check failed. Aborting rebuild."
    exit 1
fi

# If only checking, exit here
if [[ $CHECK_ONLY == true ]]; then
    echo "✅ Configuration check completed successfully!"
    exit 0
fi

# Auto-rebuild logic
if [[ $FORCE == true ]]; then
    [[ $SILENT == false ]] && echo "🔧 [$(date '+%H:%M:%S')] Force rebuilding system..."
    if sudo nixos-rebuild switch; then
        if [[ $SILENT == false ]]; then
            echo "✅ [$(date '+%H:%M:%S')] System rebuilt successfully!"
            echo "🎯 Ready to grind! Your NixOS is updated."
        fi
    else
        echo "❌ Rebuild failed! Check the error messages above."
        exit 1
    fi
else
    # Ask if user wants to rebuild (original behavior)
    read -p "🔧 Rebuild system now? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "🚀 Rebuilding system..."
        if sudo nixos-rebuild switch; then
            echo "✅ System rebuilt successfully!"
        else
            echo "❌ Rebuild failed! Check the error messages above."
            exit 1
        fi
    else
        echo "⏭️  Skipping rebuild. Run 'sudo nixos-rebuild switch' manually when ready."
    fi
fi

# Auto-commit changes if in git repo
if [[ -d .git ]] && [[ $FORCE == true ]] && [[ $SILENT == false ]]; then
    echo "📝 Auto-committing changes..."
    git add . 2>/dev/null || true
    git commit -m "Auto-update: $(date '+%Y-%m-%d %H:%M')" 2>/dev/null || echo "Nothing to commit"
fi
EOF

chmod +x sync.sh

# Create gitignore
cat >.gitignore <<'EOF'
hardware-configuration.nix
result
*.swp
*.swo
*~
EOF

echo ""
echo "✅ Setup complete! Here's what was created:"
echo "   📁 ~/wlmrNix/c.nix          - Your system configuration"
echo "   📁 ~/wlmrNix/h.nix          - Your home manager configuration"
echo "   📁 ~/wlmrNix/sync.sh        - Enhanced script with error checking"
echo "   📁 ~/wlmrNix/modules/       - Modular configuration files"
echo "   📁 ~/wlmrNix/.git           - Git repository for version control"
echo ""
echo "🔧 New features in sync.sh:"
echo "   ./sync.sh --check          - Only check configuration syntax"
echo "   ./sync.sh --force          - Force rebuild without prompting"
echo "   ./sync.sh --silent         - Run quietly"
echo ""
echo "🚀 Next steps:"
echo "   1. Run './sync.sh --check' to verify your config"
echo "   2. Run './sync.sh' to apply changes"
echo "   3. If you see Home Manager errors, the script will guide you"
echo ""
echo "🛠️  Troubleshooting:"
echo "   - If Home Manager fails: sudo nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager && sudo nix-channel --update"
echo "   - Check config syntax: ./sync.sh --check"
echo "   - For detailed errors: sudo nixos-rebuild switch --show-trace"
