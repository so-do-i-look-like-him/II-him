#!/usr/bin/env bash

# Him's Full-System Installer for Illogical Impulse (ii)
# Sets up the entire Hyprland environment + Him's custom QuickShell + Hyprland config.
#
# After install:
#   ~/.config/quickshell/ii -> $CLONE_DIR (QuickShell config)
#   ~/.config/hypr          -> $CLONE_DIR/hypr (Hyprland config)
# Local edits should be made inside $CLONE_DIR and pushed
# to the fork (https://github.com/so-do-i-look-like-him/II-him) to keep them in sync.

set -euo pipefail

# ----- Paths -----
QS_CONFIG_DIR="$HOME/.config/quickshell/ii"
QS_BACKUP_DIR="$HOME/.config/quickshell/ii_backup_$(date +%Y%m%d_%H%M%S)"
HYPR_CONFIG_DIR="$HOME/.config/hypr"
HYPR_BACKUP_DIR="$HOME/.config/hypr_backup_$(date +%Y%m%d_%H%M%S)"
CLONE_DIR=$(pwd)
TEMP_DIR=""

# ----- Cleanup: remove temp clone dir on exit (issue #9) -----
cleanup() {
    if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
}
trap cleanup EXIT

# ----- Sanity-check the working directory (issue #6) -----
if [ ! -d "$CLONE_DIR/modules" ] \
   || [ ! -d "$CLONE_DIR/services" ] \
   || [ ! -f "$CLONE_DIR/shell.qml" ] \
   || [ ! -d "$CLONE_DIR/hypr" ]; then
    echo "❌ $CLONE_DIR does not look like the ii-him repo."
    echo "   Expected to find: modules/, services/, shell.qml, hypr/"
    echo "   Please cd into your clone of so-do-i-look-like-him/II-him and re-run."
    exit 1
fi

echo "🚀 Starting Full-System Installation for Him's Setup..."
echo "This will install end-4's dots-hyprland base, then apply your custom configs."

# ----- 1. Sudo upfront -----
sudo -v

# ----- 2. Ensure base tools (issue #3: robust base-devel check) -----
echo "📦 Ensuring git and base-devel are installed..."
NEED_PKGS=()
command -v git &>/dev/null || NEED_PKGS+=(git)
# `pacman -Qg` queries groups; -Qs matches a regex against any field, which is wrong here.
if ! pacman -Qg base-devel &>/dev/null; then
    NEED_PKGS+=(base-devel)
fi
if [ ${#NEED_PKGS[@]} -gt 0 ]; then
    sudo pacman -S --needed --noconfirm "${NEED_PKGS[@]}"
fi

# ----- 2.5. Island runtime deps (issue #2 + #4: split pacman vs AUR, no error-swallowing) -----
echo "📦 Installing island runtime dependencies..."
REPO_PKGS=(cava pipewire pipewire-pulse python3 wf-recorder)
AUR_PKGS=(ttf-inter ttf-material-symbols-variable-git)
sudo pacman -S --needed --noconfirm "${REPO_PKGS[@]}"

# ----- 3. Detect AUR helper (must exist before we install AUR packages) -----
if command -v yay &>/dev/null; then
    AUR_HELPER="yay"
elif command -v paru &>/dev/null; then
    AUR_HELPER="paru"
else
    echo "❌ Neither 'yay' nor 'paru' found."
    echo "   Install one:  sudo pacman -S --needed base-devel git"
    echo "   Then:         git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si"
    exit 1
fi
echo "📦 Installing AUR packages with $AUR_HELPER: ${AUR_PKGS[*]}"
$AUR_HELPER -S --needed --noconfirm "${AUR_PKGS[@]}"

# ----- 4. Run end-4's base installer (deps + setups only, skip file copying) -----
echo "⚙️  Installing base dots-hyprland (end-4)..."
TEMP_DIR=$(mktemp -d)
git clone https://github.com/end-4/dots-hyprland.git "$TEMP_DIR/dots-hyprland"
cd "$TEMP_DIR/dots-hyprland"

echo "Running upstream installer (--skip-hyprland --skip-quickshell)... (you may need to press enter or select options)"
if ! ./setup install --skip-hyprland --skip-quickshell; then
    # Issue #5: gate continuation on explicit user confirmation
    echo ""
    echo "⚠️  Upstream installer failed."
    read -rp "Continue with partial install anyway? [y/N] " CONTINUE
    case "$CONTINUE" in
        [yY]|[yY][eE][sS]) echo "Continuing despite upstream failure — QuickShell may not work fully." ;;
        *) echo "Aborting. Re-run the script to retry."; exit 1 ;;
    esac
fi

# ----- 5. Return to repo, apply configs -----
cd "$CLONE_DIR"

# --- 5a. QuickShell symlink ---
echo "🎨 Applying Him's custom QuickShell (II-him)..."

# Backup existing config (issue #7: avoid mv into existing dir; idempotent if already correct symlink)
if [ -L "$QS_CONFIG_DIR" ] && [ "$(readlink -f "$QS_CONFIG_DIR")" = "$CLONE_DIR" ]; then
    echo "🔗 $QS_CONFIG_DIR already symlinks to this repo. Skipping backup."
elif [ -e "$QS_CONFIG_DIR" ] || [ -L "$QS_CONFIG_DIR" ]; then
    rm -rf "$QS_BACKUP_DIR" 2>/dev/null || true
    mv "$QS_CONFIG_DIR" "$QS_BACKUP_DIR"
    echo "📦 Backed up existing QuickShell config to $QS_BACKUP_DIR"
fi
ln -s "$CLONE_DIR" "$QS_CONFIG_DIR"
echo "🔗 Linked $QS_CONFIG_DIR -> $CLONE_DIR"

# --- 5b. Hyprland symlink ---
echo "🎨 Applying Hyprland config..."
HYPR_DIR="$CLONE_DIR/hypr"

# Capture user's custom overrides before replacing the directory
USER_CUSTOM_DIR=""
if [ -d "$HYPR_CONFIG_DIR/custom" ] && [ ! -L "$HYPR_CONFIG_DIR/custom" ]; then
    USER_CUSTOM_DIR=$(mktemp -d)
    cp -a "$HYPR_CONFIG_DIR/custom/." "$USER_CUSTOM_DIR/"
    echo "📋 Captured existing custom overrides for restoration"
fi

# Rename stale hyprland.conf so lua config loads (upstream convention)
if [ -f "$HYPR_CONFIG_DIR/hyprland.conf" ] && [ ! -L "$HYPR_CONFIG_DIR/hyprland.conf" ]; then
    mv "$HYPR_CONFIG_DIR/hyprland.conf" "$HYPR_CONFIG_DIR/hyprland.conf.old"
    echo "📝 Renamed hyprland.conf -> hyprland.conf.old (lua config takes over)"
fi

if [ -L "$HYPR_CONFIG_DIR" ] && [ "$(readlink -f "$HYPR_CONFIG_DIR")" = "$HYPR_DIR" ]; then
    echo "🔗 $HYPR_CONFIG_DIR already symlinks to $HYPR_DIR. Skipping backup."
elif [ -e "$HYPR_CONFIG_DIR" ] || [ -L "$HYPR_CONFIG_DIR" ]; then
    rm -rf "$HYPR_BACKUP_DIR" 2>/dev/null || true
    mv "$HYPR_CONFIG_DIR" "$HYPR_BACKUP_DIR"
    echo "📦 Backed up existing Hyprland config to $HYPR_BACKUP_DIR"
fi
ln -s "$HYPR_DIR" "$HYPR_CONFIG_DIR"
echo "🔗 Linked $HYPR_CONFIG_DIR -> $HYPR_DIR"

# Restore user's custom overrides into the symlinked repo dir
if [ -n "$USER_CUSTOM_DIR" ] && [ -d "$USER_CUSTOM_DIR" ]; then
    mkdir -p "$HYPR_DIR/custom"
    cp -a "$USER_CUSTOM_DIR/." "$HYPR_DIR/custom/"
    rm -rf "$USER_CUSTOM_DIR"
    echo "♻️  Restored custom overrides into $HYPR_DIR/custom/"
fi

# ----- 6. Initialize remotes (issue #10: idempotent upstream add) -----
echo "🔗 Setting up GitHub remotes..."
git remote set-url origin https://github.com/so-do-i-look-like-him/II-him.git
# Upstream: end-4's full dots-hyprland (their QuickShell config lives inside this repo)
if ! git remote get-url upstream &>/dev/null; then
    git remote add upstream https://github.com/end-4/dots-hyprland.git
fi
git remote -v

# ----- 7. Make scripts executable (issue #11: check existence, chmod all .sh) -----
echo "🔧 Making scripts executable..."
SCRIPT="$QS_CONFIG_DIR/scripts/detect-screenshare.sh"
if [ -e "$SCRIPT" ]; then
    chmod +x "$SCRIPT"
else
    echo "   ⚠️  $SCRIPT not found (was the repo updated?)"
fi
# Defensive: ensure any new .sh added to scripts/ is also executable
if [ -d "$QS_CONFIG_DIR/scripts" ]; then
    find "$QS_CONFIG_DIR/scripts" -type f -name "*.sh" -exec chmod +x {} +
fi
# Also make hyprland scripts executable
if [ -d "$HYPR_DIR/hyprland/scripts" ]; then
    find "$HYPR_DIR/hyprland/scripts" -type f -name "*.sh" -exec chmod +x {} +
fi
if [ -d "$HYPR_DIR/custom/scripts" ]; then
    find "$HYPR_DIR/custom/scripts" -type f -name "*.sh" -exec chmod +x {} +
fi

# ----- 8. Restart QuickShell (issue #12 + #13: graceful kill, log to file) -----
echo "🔄 Restarting QuickShell..."
pkill -TERM -x qs         2>/dev/null || true
pkill -TERM -x quickshell 2>/dev/null || true
sleep 1
pkill -KILL -x qs         2>/dev/null || true
pkill -KILL -x quickshell 2>/dev/null || true

QS_LOG="/tmp/qs-restart-$(date +%s).log"
if command -v qs &>/dev/null; then
    nohup qs -c "$QS_CONFIG_DIR" >"$QS_LOG" 2>&1 &
elif command -v quickshell &>/dev/null; then
    nohup quickshell -c "$QS_CONFIG_DIR" >"$QS_LOG" 2>&1 &
else
    echo "ℹ️  QuickShell binary not found. Start it manually: qs -c $QS_CONFIG_DIR"
    QS_LOG=""
fi

if [ -n "$QS_LOG" ]; then
    sleep 2
    if pgrep -x qs >/dev/null || pgrep -x quickshell >/dev/null; then
        echo "✅ QuickShell restarted. Log: $QS_LOG"
    else
        echo "⚠️  QuickShell failed to start. Log: $QS_LOG"
        echo "--- log tail ---"
        tail -20 "$QS_LOG" || true
    fi
fi

echo ""
echo "✅ Full Installation Complete!"
echo "Your system now has the end-4 base + your personal QuickShell + Hyprland configs."
echo ""
echo "💡 Island features:"
echo "   • Clock + Audio Visualizer (cava)"
echo "   • Recording Indicator (wf-recorder detection)"
echo "   • Screen Sharing Indicator (PipeWire detection)"
echo "   • OSD (brightness/volume)"
echo "   • Workspace indicator (super hold)"
echo "   • Inline notifications"
echo ""
echo "📂 Config locations:"
echo "   QuickShell:  ~/.config/quickshell/ii -> $CLONE_DIR"
echo "   Hyprland:    ~/.config/hypr          -> $HYPR_DIR"
