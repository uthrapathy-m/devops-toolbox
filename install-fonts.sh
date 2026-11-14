#!/usr/bin/env bash
# DevOps Toolbox — terminal fonts for YOUR macOS / Linux desktop (the SSH client side).
# Installs CaskaydiaMono Nerd Font + JetBrainsMono Nerd Font for the current user.
#
#   curl -fsSL https://raw.githubusercontent.com/uthrapathy-m/devops-toolbox/main/install-fonts.sh | bash
#   bash install-fonts.sh --dry-run      # download + list only
set -eo pipefail

DRY=0; FORCE=0
for a in "$@"; do case "$a" in --dry-run) DRY=1 ;; --force) FORCE=1 ;; esac; done
if [ -t 1 ]; then C=$'\e[36m'; G=$'\e[32m'; Y=$'\e[33m'; D=$'\e[2m'; R=$'\e[0m'; else C=; G=; Y=; D=; R=; fi

# Fonts are rendered by the SSH *client*. On a remote server with no desktop, installing them does nothing.
if [ "$(uname -s)" = Linux ] && [ -n "${SSH_CONNECTION:-}" ] && [ -z "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ] && [ "$FORCE" = 0 ]; then
  cat >&2 <<EOF

  ${Y}⚠ You're on a remote server over SSH. Fonts installed here won't change how your terminal looks.${R}
    Your terminal draws text with fonts from the computer you SSH *from*. Run this there instead:

    ${C}Windows (PowerShell):${R}  irm https://raw.githubusercontent.com/uthrapathy-m/devops-toolbox/main/install-fonts.ps1 | iex
    ${C}macOS / Linux desktop:${R} curl -fsSL https://raw.githubusercontent.com/uthrapathy-m/devops-toolbox/main/install-fonts.sh | bash

    ${D}(Use --force to install here anyway, e.g. for a desktop session on this machine.)${R}

EOF
  exit 1
fi

case "$(uname -s)" in
  Darwin) FONT_DIR="$HOME/Library/Fonts" ;;
  Linux)  FONT_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/fonts/devops-toolbox" ;;
  *) echo "Unsupported OS: $(uname -s). On Windows use install-fonts.ps1." >&2; exit 1 ;;
esac
for c in curl unzip; do command -v "$c" >/dev/null || { echo "Missing required command: $c" >&2; exit 1; }; done

printf '\n  %sDEVOPS TOOLBOX · terminal fonts%s\n' "$C" "$R"
printf '  %s============================================================%s\n' "$C" "$R"
printf '  %s➜%s Installing for %s → %s\n' "$C" "$R" "${USER:-$(id -un)}" "$FONT_DIR"
[ "$DRY" = 1 ] && printf '  %s⚠%s Dry run: downloading and listing only.\n' "$Y" "$R"
echo

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
[ "$DRY" = 1 ] || mkdir -p "$FONT_DIR"

install_font() {  # zip-name family file-glob
  local zip=$1 family=$2 glob=$3 n=0 f
  local url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/$zip.zip"
  printf '  %s↓ %s  (%s)%s\n' "$D" "$family" "$url" "$R"
  curl -fsSL --retry 3 -o "$TMP/$zip.zip" "$url"
  mkdir -p "$TMP/$zip"; unzip -qo "$TMP/$zip.zip" -d "$TMP/$zip"
  for f in "$TMP/$zip"/$glob; do
    [ -e "$f" ] || continue
    [ "$DRY" = 1 ] || cp -f "$f" "$FONT_DIR/"
    n=$((n + 1))
  done
  [ "$n" -gt 0 ] || { echo "No $glob files in $zip.zip" >&2; return 1; }
  printf '  %s✔%s %-30s %s %s styles\n' "$G" "$R" "$family" "$([ "$DRY" = 1 ] && echo 'would install' || echo installed)" "$n"
}

install_font CascadiaMono  "CaskaydiaMono Nerd Font Mono" "CaskaydiaMonoNerdFontMono-*.ttf"
install_font JetBrainsMono "JetBrainsMono Nerd Font Mono" "JetBrainsMonoNerdFontMono-*.ttf"

if [ "$DRY" = 0 ] && command -v fc-cache >/dev/null; then fc-cache -f "$FONT_DIR" >/dev/null 2>&1 || true; fi

cat <<EOF

  ${C}============================================================${R}
  ${C}Done. Restart your terminal, then select the font:${R}
    iTerm2          Settings → Profiles → Text → Font
    macOS Terminal  Settings → Profiles → Text → Change…
    GNOME Terminal  Preferences → Profile → Custom font
    kitty           font_family JetBrainsMono Nerd Font Mono      (~/.config/kitty/kitty.conf)
    Alacritty       [font.normal] family = "JetBrainsMono Nerd Font Mono"
    VS Code         "terminal.integrated.fontFamily": "JetBrainsMono Nerd Font Mono"

EOF
