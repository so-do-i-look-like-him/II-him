#!/usr/bin/env bash
# ───────────────────────────────────────────────────────
#  Him's Simple Installer for II-him
#  Usage: cd ~/II-him && bash install.sh
# ───────────────────────────────────────────────────────
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
QS_LINK="$HOME/.config/quickshell/ii"
HYPR_LINK="$HOME/.config/hypr"
QS_BACKUP="$HOME/.config/quickshell/ii_backup_$(date +%Y%m%d_%H%M%S)"
HYPR_BACKUP="$HOME/.config/hypr_backup_$(date +%Y%m%d_%H%M%S)"
END4_MARKER="$HOME/.local/share/ii-him/end4-installed"

# ── Sanity check ──────────────────────────────────────┬─
if [ ! -d "$REPO_DIR/modules" ] || [ ! -f "$REPO_DIR/shell.qml" ] || [ ! -d "$REPO_DIR/hypr" ]; then
    echo "❌ This doesn't look like the II-him repo."
    echo "   Missing: modules/, shell.qml, or hypr/"
    echo "   cd into your II-him clone and re-run."
    exit 1
fi

# ── Colours ───────────────────────────────────────────┬─
RST='\033[0m'; RED='\033[0;31m'; GRN='\033[0;32m'; YLW='\033[0;33m'; BLU='\033[0;34m'
info()  { echo -e "${BLU}ℹ${RST}  $*"; }
ok()    { echo -e "${GRN}✔${RST}  $*"; }
warn()  { echo -e "${YLW}⚠${RST}  $*"; }
err()   { echo -e "${RED}✖${RST}  $*"; }

info "II-him installer starting…"
echo ""

# ═══════════════════════════════════════════════════════════
#  1.  end-4 base dependencies & services
# ═══════════════════════════════════════════════════════════

if [ -f "$END4_MARKER" ]; then
    ok "end-4 base already installed (marker found). Skipping."
else
    echo ""
    info "Step 1 — Install end-4's base dependencies & services"
    echo "     This will:"
    echo "     • Install required packages (pacman + AUR)"
    echo "     • Set up Pipewire, services, permissions"
    echo "     • Skip Hyprland and QuickShell configs (we bring our own)"
    echo ""

    # Confirm
    read -rp "   Proceed with end-4 base install? [Y/n] " CONFIRM
    case "$CONFIRM" in
        [nN]|[nN][oO]) echo "   Skipped by user." ;;
        *)
            TEMP_DIR=$(mktemp -d)
            trap 'rm -rf "$TEMP_DIR"' EXIT

            info "Cloning end-4/dots-hyprland…"
            git clone --depth=1 https://github.com/end-4/dots-hyprland.git "$TEMP_DIR/dots-hyprland"

            cd "$TEMP_DIR/dots-hyprland"

            echo ""
            info "Running upstream installer (--skip-hyprland --skip-quickshell)…"
            echo "     (You may need to press Enter or confirm prompts.)"
            if ! ./setup install --force --skip-hyprland --skip-quickshell; then
                echo ""
                warn "Upstream installer had issues."
                read -rp "   Continue anyway? [y/N] " CONTINUE
                case "$CONTINUE" in
                    [yY]|[yY][eE][sS]) warn "Continuing despite errors…" ;;
                    *) err "Aborted."; exit 1 ;;
                esac
            fi

            mkdir -p "$(dirname "$END4_MARKER")"
            date > "$END4_MARKER"
            ok "end-4 base installed. Marker saved."
            cd "$REPO_DIR"
            ;;
    esac
fi

# ═══════════════════════════════════════════════════════════
#  2.  Island runtime deps (pacman)
# ═══════════════════════════════════════════════════════════

echo ""
info "Step 2 — Install island runtime packages (pacman)"
REPO_PKGS=(cava pipewire pipewire-pulse python3 wf-recorder inter-font)
MISSING=()
for pkg in "${REPO_PKGS[@]}"; do
    pacman -Q "$pkg" &>/dev/null || MISSING+=("$pkg")
done
if [ ${#MISSING[@]} -eq 0 ]; then
    ok "All runtime packages already installed."
else
    info "Installing: ${MISSING[*]}"
    sudo pacman -S --needed --noconfirm "${MISSING[@]}"
    ok "Runtime packages installed."
fi

# ═══════════════════════════════════════════════════════════
#  3.  AUR packages
# ═══════════════════════════════════════════════════════════

echo ""
info "Step 3 — Install AUR packages"
# Note: ttf-material-symbols-variable-git is from AUR.
# inter-font is from official repos (step 2) — avoids the broken
# ttf-google-fonts-typewolf that ttf-inter now maps to.
AUR_PKGS=(ttf-material-symbols-variable-git)

# Detect AUR helper
AUR_HELPER=""
for helper in yay paru; do
    if command -v "$helper" &>/dev/null; then
        AUR_HELPER="$helper"
        break
    fi
done
if [ -z "$AUR_HELPER" ]; then
    err "Neither yay nor paru found. Install one first."
    err "  sudo pacman -S --needed base-devel git"
    err "  git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si"
    exit 1
fi

MISSING_AUR=()
for pkg in "${AUR_PKGS[@]}"; do
    pacman -Q "$pkg" &>/dev/null || MISSING_AUR+=("$pkg")
done
if [ ${#MISSING_AUR[@]} -eq 0 ]; then
    ok "All AUR packages already installed."
else
    info "Installing with $AUR_HELPER: ${MISSING_AUR[*]}"
    $AUR_HELPER -S --needed --noconfirm "${MISSING_AUR[@]}"
    ok "AUR packages installed."
fi

# ═══════════════════════════════════════════════════════════
#  4.  QuickShell symlink
# ═══════════════════════════════════════════════════════════

echo ""
info "Step 4 — Link QuickShell config"
if [ -L "$QS_LINK" ] && [ "$(readlink -f "$QS_LINK")" = "$REPO_DIR" ]; then
    ok "QuickShell already linked to this repo."
else
    if [ -e "$QS_LINK" ] || [ -L "$QS_LINK" ]; then
        rm -rf "$QS_BACKUP" 2>/dev/null || true
        mv "$QS_LINK" "$QS_BACKUP"
        info "Backed up existing config → $QS_BACKUP"
    fi
    ln -s "$REPO_DIR" "$QS_LINK"
    ok "Linked $QS_LINK → $REPO_DIR"
fi

# ═══════════════════════════════════════════════════════════
#  5.  Hyprland symlink (preserving custom/ overrides)
# ═══════════════════════════════════════════════════════════

echo ""
info "Step 5 — Link Hyprland config"

# Capture existing custom overrides before touching hypr dir
USER_CUSTOM_DIR=""
if [ -d "$HYPR_LINK/custom" ] && [ ! -L "$HYPR_LINK/custom" ]; then
    USER_CUSTOM_DIR=$(mktemp -d)
    cp -a "$HYPR_LINK/custom/." "$USER_CUSTOM_DIR/"
    info "Captured existing custom/ overrides"
fi

# Rename stale hyprland.conf so lua config takes over
if [ -f "$HYPR_LINK/hyprland.conf" ] && [ ! -L "$HYPR_LINK/hyprland.conf" ]; then
    mv "$HYPR_LINK/hyprland.conf" "$HYPR_LINK/hyprland.conf.old"
    info "Renamed hyprland.conf → hyprland.conf.old (lua config takes over)"
fi

HYPR_DIR="$REPO_DIR/hypr"
if [ -L "$HYPR_LINK" ] && [ "$(readlink -f "$HYPR_LINK")" = "$HYPR_DIR" ]; then
    ok "Hyprland already linked to this repo."
else
    if [ -e "$HYPR_LINK" ] || [ -L "$HYPR_LINK" ]; then
        rm -rf "$HYPR_BACKUP" 2>/dev/null || true
        mv "$HYPR_LINK" "$HYPR_BACKUP"
        info "Backed up existing config → $HYPR_BACKUP"
    fi
    ln -s "$HYPR_DIR" "$HYPR_LINK"
    ok "Linked $HYPR_LINK → $HYPR_DIR"
fi

# Restore custom overrides into the now-symlinked repo dir
if [ -n "$USER_CUSTOM_DIR" ] && [ -d "$USER_CUSTOM_DIR" ]; then
    mkdir -p "$HYPR_DIR/custom"
    cp -a "$USER_CUSTOM_DIR/." "$HYPR_DIR/custom/"
    rm -rf "$USER_CUSTOM_DIR"
    ok "Restored custom overrides into $HYPR_DIR/custom/"
fi

# ═══════════════════════════════════════════════════════════
#  6.  Make scripts executable
# ═══════════════════════════════════════════════════════════

echo ""
info "Step 6 — Make scripts executable"
for dir in "$REPO_DIR/scripts" "$REPO_DIR/hypr/hyprland/scripts" "$REPO_DIR/hypr/custom/scripts"; do
    if [ -d "$dir" ]; then
        find "$dir" -type f -name "*.sh" -exec chmod +x {} + 2>/dev/null || true
        ok "Made scripts executable in $dir"
    fi
done

# ═══════════════════════════════════════════════════════════
#  7.  Restart QuickShell
# ═══════════════════════════════════════════════════════════

echo ""
info "Step 7 — Restart QuickShell"

pkill -TERM -x qs 2>/dev/null || true
pkill -TERM -x quickshell 2>/dev/null || true
sleep 1
pkill -KILL -x qs 2>/dev/null || true
pkill -KILL -x quickshell 2>/dev/null || true

QS_LOG="/tmp/qs-restart-$(date +%s).log"
QS_BIN=""
command -v qs &>/dev/null && QS_BIN="qs" || command -v quickshell &>/dev/null && QS_BIN="quickshell"

if [ -n "$QS_BIN" ]; then
    nohup "$QS_BIN" -c "$QS_LINK" >"$QS_LOG" 2>&1 &
    sleep 2
    if pgrep -x qs >/dev/null || pgrep -x quickshell >/dev/null; then
        ok "QuickShell restarted. Log: $QS_LOG"
    else
        warn "QuickShell may not have started. Log: $QS_LOG"
        tail -5 "$QS_LOG" 2>/dev/null || true
    fi
else
    warn "QuickShell binary not found. Start manually: qs -c $QS_LINK"
fi

# ── Done ───────────────────────────────────────────────┬─

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ok "Installation complete!"
echo ""
echo "  QuickShell:  $QS_LINK → $REPO_DIR"
echo "  Hyprland:    $HYPR_LINK → $HYPR_DIR"
echo ""
echo "  💡 Log out & back in for everything to take effect."
echo "     Or run: qs -c $QS_LINK"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
