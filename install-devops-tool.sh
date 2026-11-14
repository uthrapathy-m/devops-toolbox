#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════════╗
# ║  DevOps Toolbox — interactive productivity installer for new servers ║
# ║  curl -fsSL https://raw.githubusercontent.com/uthrapathy-m/devops-toolbox/main/install-devops-tool.sh | bash
# ╚══════════════════════════════════════════════════════════════════════╝
# Supports: Ubuntu/Debian (apt), RHEL/Rocky/Alma/CentOS/Fedora/Amazon Linux (dnf/yum)
# Arch:     x86_64, arm64
set -o pipefail

TOOLBOX_VERSION="1.0.0"
TOOLBOX_REPO="uthrapathy-m/devops-toolbox"
TOOLBOX_HOME="$HOME/.devops-toolbox"
STATE_FILE="$TOOLBOX_HOME/state"
BINS_FILE="$TOOLBOX_HOME/bins.list"
LOG_DIR="$TOOLBOX_HOME/logs"
BASHRC_LINE='[ -f "$HOME/.devops-toolbox/init.sh" ] && . "$HOME/.devops-toolbox/init.sh"  # devops-toolbox'

# ───────────────────────────── colours ──────────────────────────────
if [ -t 1 ]; then
  R=$'\e[0m'; B=$'\e[1m'; DIM=$'\e[2m'; RED=$'\e[31m'; GRN=$'\e[32m'; YLW=$'\e[33m'
  BLU=$'\e[34m'; MAG=$'\e[35m'; CYN=$'\e[36m'; INV=$'\e[7m'; EL=$'\e[K'
else
  R=; B=; DIM=; RED=; GRN=; YLW=; BLU=; MAG=; CYN=; INV=; EL=
fi
ok()   { printf "  ${GRN}✔${R} %s\n" "$*"; }
info() { printf "  ${CYN}➜${R} %s\n" "$*"; }
warn() { printf "  ${YLW}⚠${R} %s\n" "$*"; }
err()  { printf "  ${RED}✖${R} %s\n" "$*" >&2; }
die()  { err "$*"; exit 1; }

# ───────────────────────────── options ──────────────────────────────
OPT_PROFILE=""; OPT_TOOLS=""; OPT_YES=0; OPT_UPGRADE=0; OPT_UNINSTALL=0; OPT_LIST=0; OPT_NO_BANNER=0; OPT_THEME=""; OPT_NO_TRAEFIK=""

usage() {
  cat <<EOF
${B}DevOps Toolbox v$TOOLBOX_VERSION${R} — interactive installer for DevOps productivity tools

${B}Usage${R}
  curl -fsSL https://raw.githubusercontent.com/$TOOLBOX_REPO/main/install-devops-tool.sh | bash
  curl -fsSL .../install-devops-tool.sh | bash -s -- [options]

${B}Options${R}
  -p, --profile NAME   Preselect a profile: minimal | core | k8s | cloud | everything | custom
  -t, --tools a,b,c    Preselect exact items (see --list); combines with --profile
  -y, --yes            Non-interactive: install the preselection without menus
  -u, --upgrade        Reinstall items that are already installed (latest versions)
      --no-banner      Do not show the login banner
      --theme NAME     Banner colours: ocean (default) | amber | ice | snow | matrix | sand | lavender
      --no-traefik     With the k3s item: install k3s without the Traefik ingress
      --list           List every item id and exit
      --uninstall      Remove toolbox shell config and binaries it installed
  -h, --help           Show this help

${B}Examples${R}
  bash install-devops-tool.sh                          # full interactive menu
  bash install-devops-tool.sh -p k8s -y                # K8s Ops profile, no questions
  bash install-devops-tool.sh -t fzf,btop,zoxide -y    # just these
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    -p|--profile) OPT_PROFILE="$2"; shift ;;
    --profile=*)  OPT_PROFILE="${1#*=}" ;;
    -t|--tools)   OPT_TOOLS="$2"; shift ;;
    --tools=*)    OPT_TOOLS="${1#*=}" ;;
    -y|--yes)     OPT_YES=1 ;;
    -u|--upgrade) OPT_UPGRADE=1 ;;
    --no-banner)  OPT_NO_BANNER=1 ;;
    --theme)      OPT_THEME="$2"; shift ;;
    --no-traefik) OPT_NO_TRAEFIK=1 ;;
    --theme=*)    OPT_THEME="${1#*=}" ;;
    --list)       OPT_LIST=1 ;;
    --uninstall)  OPT_UNINSTALL=1 ;;
    -h|--help)    usage; exit 0 ;;
    *) die "Unknown option: $1 (see --help)" ;;
  esac
  shift
done

# ───────────────────────────── catalog ──────────────────────────────
# Every Item: id | category | kind | binary | label | description
CATEGORIES=(cli mon k8s cloud shell)
declare -A CAT_NAME=(
  [cli]="CLI Utilities" [mon]="Monitoring" [k8s]="Containers & Kubernetes"
  [cloud]="Cloud & IaC" [shell]="Aliases & Dotfiles"
)
IDS=()
declare -A I_CAT I_KIND I_BIN I_LABEL I_DESC
item() { IDS+=("$1"); I_CAT[$1]=$2; I_KIND[$1]=$3; I_BIN[$1]=$4; I_LABEL[$1]=$5; I_DESC[$1]=$6; }

item fzf          cli   tool  fzf        "fzf"            "Fuzzy finder (Ctrl-R history, Ctrl-T files)"
item zoxide       cli   tool  zoxide     "zoxide (z)"     "Smarter cd that learns your dirs"
item bat          cli   tool  bat        "bat"            "cat with syntax highlighting"
item eza          cli   tool  eza        "eza"            "Modern ls with git status & tree"
item ripgrep      cli   tool  rg         "ripgrep (rg)"   "Blazing fast recursive grep"
item fd           cli   tool  fd         "fd"             "Simple, fast alternative to find"
item jq           cli   tool  jq         "jq"             "JSON processor"
item yq           cli   tool  yq         "yq"             "YAML / JSON / XML processor"
item tldr         cli   tool  tldr       "tldr"           "Simplified man pages (tealdeer)"
item ncdu         cli   tool  ncdu       "ncdu"           "Interactive disk usage explorer"
item tmux         cli   tool  tmux       "tmux"           "Terminal multiplexer"
item delta        cli   tool  delta      "git-delta"      "Beautiful side-by-side git diffs"
item lazygit      cli   tool  lazygit    "lazygit"        "Terminal UI for git"
item starship     cli   tool  starship   "starship"       "Fast prompt: git, k8s ctx, exit code"
item btop         mon   tool  btop       "btop"           "Gorgeous resource monitor"
item htop         mon   tool  htop       "htop"           "Classic process viewer"
item fastfetch    mon   tool  fastfetch  "fastfetch"      "System info + custom login banner"
item docker       k8s   tool  docker     "docker"         "Docker Engine + Compose plugin"
item kubectl      k8s   tool  kubectl    "kubectl"        "Kubernetes CLI"
item helm         k8s   tool  helm       "helm"           "Kubernetes package manager"
item k9s          k8s   tool  k9s        "k9s"            "Kubernetes terminal UI"
item kubectx      k8s   tool  kubectx    "kubectx/kubens" "Switch contexts & namespaces fast"
item stern        k8s   tool  stern      "stern"          "Tail logs from many pods"
item sofka        k8s   tool  sofka      "sofka"          "Rust Kubernetes TUI (k9s alternative)"
item k3d          k8s   tool  k3d        "k3d"            "k3s clusters in Docker (multi-node, quick)"
item k3s          k8s   tool  k3s        "k3s server"     "Real k3s cluster on this machine (systemd)"
item lazydocker   k8s   tool  lazydocker "lazydocker"     "Terminal UI for docker"
item dive         k8s   tool  dive       "dive"           "Explore docker image layers"
item terraform    cloud tool  terraform  "terraform"      "HashiCorp infrastructure as code"
item opentofu     cloud tool  tofu       "opentofu"       "Open-source Terraform fork"
item ansible      cloud tool  ansible    "ansible"        "Configuration management"
item awscli       cloud tool  aws        "aws cli v2"     "Amazon Web Services CLI"
item azure        cloud tool  az         "azure cli"      "Microsoft Azure CLI"
item gcloud       cloud tool  gcloud     "gcloud"         "Google Cloud CLI"
item alias-general shell alias -         "General aliases"    "ll, .., mkcd, extract, ports, myip"
item alias-git     shell alias -         "Git aliases"        "gs, ga, gc, gp, gl, gd, gco"
item alias-k8s     shell alias -         "Kubernetes aliases" "k, kgp, kgs, kl, kex + completion"
item alias-docker  shell alias -         "Docker aliases"     "d, dps, dc, dcu, dlog, dex"
item dot-tmux      shell dotfile -       "tmux.conf"          "Mouse, sane splits, nice status bar"
item dot-fzf       shell dotfile -       "fzf defaults"       "fd-powered search + bat previews"
item dot-k8s-tui   shell dotfile -       "k9s / sofka setup"  "Themed skins, plugins, hotkeys, aliases"
item tmux-bar      shell dotfile -       "tmux top bar"       "Sticky themed top bar + auto tmux on SSH"

PROFILES=(minimal core k8s cloud everything custom)
declare -A P_NAME=(
  [minimal]="Minimal" [core]="Core CLI" [k8s]="K8s Ops" [cloud]="Cloud"
  [everything]="Everything" [custom]="Custom"
)
declare -A P_DESC=(
  [minimal]="fzf, zoxide, bat, btop + general/git aliases"
  [core]="All modern CLI utilities, tmux, starship, dotfiles"
  [k8s]="Core CLI + docker, kubectl, helm, k9s, sofka, stern"
  [cloud]="Core CLI + terraform, opentofu, ansible, aws/az/gcloud"
  [everything]="Every item in the catalog"
  [custom]="Start from nothing, pick item by item"
)
_P_MIN="fzf zoxide bat btop fastfetch alias-general alias-git"
_P_CORE="$_P_MIN eza ripgrep fd jq yq tldr ncdu tmux delta lazygit starship htop dot-tmux dot-fzf tmux-bar"
declare -A P_ITEMS=(
  [minimal]="$_P_MIN"
  [core]="$_P_CORE"
  [k8s]="$_P_CORE docker kubectl helm k9s sofka k3d kubectx stern lazydocker dive alias-k8s alias-docker dot-k8s-tui"
  [cloud]="$_P_CORE terraform opentofu ansible awscli azure gcloud"
  [everything]="${IDS[*]}"
  [custom]="fastfetch"
)

if [ "$OPT_LIST" = 1 ]; then
  for c in "${CATEGORIES[@]}"; do
    printf "\n${B}%s${R}\n" "${CAT_NAME[$c]}"
    for id in "${IDS[@]}"; do [ "${I_CAT[$id]}" = "$c" ] && printf "  %-14s %s\n" "$id" "${I_DESC[$id]}"; done
  done
  printf "\n${B}Profiles${R}\n"; for p in "${PROFILES[@]}"; do printf "  %-14s %s\n" "$p" "${P_DESC[$p]}"; done
  exit 0
fi

# ──────────────────────────── environment ───────────────────────────
TMP="$(mktemp -d 2>/dev/null || mktemp -d -t devops-toolbox)"
SUDO_KEEPALIVE_PID=""
cleanup() {
  [ -n "$SUDO_KEEPALIVE_PID" ] && kill "$SUDO_KEEPALIVE_PID" 2>/dev/null
  rm -rf "$TMP"
  [ -t 1 ] && printf '\e[?25h'   # always restore cursor
}
trap cleanup EXIT
trap 'echo; err "Aborted."; exit 130' INT TERM

detect_os() {
  [ "$(uname -s)" = "Linux" ] || die "This installer targets Linux servers (found $(uname -s))."
  # shellcheck disable=SC1091
  . /etc/os-release 2>/dev/null || die "Cannot read /etc/os-release"
  OS_ID="${ID:-unknown}"; OS_LIKE="${ID_LIKE:-}"; OS_PRETTY="${PRETTY_NAME:-$OS_ID}"
  if command -v apt-get >/dev/null; then PKG=apt
  elif command -v dnf >/dev/null;   then PKG=dnf
  elif command -v yum >/dev/null;   then PKG=yum
  else die "Unsupported distro: need apt, dnf or yum."; fi
  case "$(uname -m)" in
    x86_64|amd64)  ARCH=amd64; ARCH_X=x86_64;  ARCH_RE='(x86_64|amd64|x64)' ;;
    aarch64|arm64) ARCH=arm64; ARCH_X=aarch64; ARCH_RE='(aarch64|arm64)' ;;
    *) die "Unsupported CPU architecture: $(uname -m)" ;;
  esac
}

HAS_ROOT=0; SUDO=""
detect_privileges() {
  if [ "$(id -u)" -eq 0 ]; then HAS_ROOT=1; SUDO=""
  elif command -v sudo >/dev/null 2>&1; then
    if sudo -n true 2>/dev/null; then HAS_ROOT=1; SUDO="sudo"
    elif [ "$OPT_YES" = 0 ] && [ -r /dev/tty ]; then
      local a
      printf "  ${CYN}?${R} Use sudo for system-wide installs (package manager, docker)? ${DIM}[Y/n]${R} "
      IFS= read -r a </dev/tty
      if [[ ! "$a" =~ ^[Nn] ]] && sudo -v </dev/tty; then HAS_ROOT=1; SUDO="sudo"
      else warn "Continuing without sudo — tools go to ~/.local/bin, package-only tools will be skipped."; fi
    fi
  fi
  if [ "$HAS_ROOT" = 1 ]; then
    BIN_DIR=/usr/local/bin
    if [ -n "$SUDO" ]; then   # keep sudo timestamp fresh while we work
      ( while kill -0 $$ 2>/dev/null; do sudo -n true 2>/dev/null; sleep 50; done ) &
      SUDO_KEEPALIVE_PID=$!
    fi
  else
    BIN_DIR="$HOME/.local/bin"
  fi
  mkdir -p "$HOME/.local/bin" "$TOOLBOX_HOME" "$LOG_DIR"
  export PATH="$BIN_DIR:$HOME/.local/bin:$PATH"
}

# ──────────────────────────── helpers ───────────────────────────────
APT_UPDATED=0
pkg_install() {
  [ "$HAS_ROOT" = 1 ] || { echo "needs sudo/root for package manager"; return 1; }
  case "$PKG" in
    apt)
      if [ "$APT_UPDATED" = 0 ]; then $SUDO apt-get update -y || true; APT_UPDATED=1; fi
      $SUDO env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$@" ;;
    dnf) $SUDO dnf install -y "$@" ;;
    yum) $SUDO yum install -y "$@" ;;
  esac
}
enable_epel() {
  [ "$PKG" = apt ] && return 0
  case "$OS_ID" in
    amzn) command -v amazon-linux-extras >/dev/null && $SUDO amazon-linux-extras install -y epel ;;
    fedora) : ;;
    rhel) local v; v=$(rpm -E %rhel); $SUDO $PKG install -y "https://dl.fedoraproject.org/pub/epel/epel-release-latest-$v.noarch.rpm" ;;
    *) pkg_install epel-release ;;
  esac
  return 0
}
pkg_install_epel() { pkg_install "$@" || { enable_epel; pkg_install "$@"; }; }

dl() { curl -fsSL --retry 3 --connect-timeout 15 -o "$2" "$1"; }

CURL_AUTH=()
[ -n "${GITHUB_TOKEN:-}" ] && CURL_AUTH=(-H "Authorization: Bearer $GITHUB_TOKEN")
gh_json() {   # cached /releases/latest JSON for owner/repo
  local f="$TMP/gh_${1//\//_}.json"
  [ -s "$f" ] || curl -fsSL --retry 3 "${CURL_AUTH[@]}" -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/$1/releases/latest" -o "$f" || { echo "GitHub API failed for $1 (rate limit? export GITHUB_TOKEN)" >&2; return 1; }
  cat "$f"
}
gh_tag() { gh_json "$1" | grep -m1 '"tag_name"' | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/'; }
gh_asset() {  # gh_asset owner/repo pattern...   (@ARCH@ is replaced by the arch regex)
  local repo=$1 urls pat u; shift
  urls=$(gh_json "$repo" | grep -oE '"browser_download_url": *"[^"]+"' | sed -E 's/.*"(https[^"]+)"$/\1/') || return 1
  for pat in "$@"; do
    pat=${pat//@ARCH@/$ARCH_RE}
    u=$(grep -iE "$pat" <<<"$urls" | head -1)
    [ -n "$u" ] && { echo "$u"; return 0; }
  done
  echo "No release asset for $repo matching: $*"; return 1
}

place_bin() {  # place_bin <file> <name>
  local dest="$BIN_DIR/$2"
  if [ "$HAS_ROOT" = 1 ]; then $SUDO install -m 0755 "$1" "$dest"; else install -m 0755 "$1" "$dest"; fi || return 1
  grep -qxF "$dest" "$BINS_FILE" 2>/dev/null || echo "$dest" >> "$BINS_FILE"
}

fetch_install() {  # fetch_install <url> <binary> [binary...]  — archive or raw binary
  local url=$1 d f b p; shift
  d=$(mktemp -d "$TMP/x.XXXXXX"); f="$d/$(basename "${url%%\?*}")"
  echo "↓ $url"; dl "$url" "$f" || return 1
  mkdir -p "$d/out"
  case "$f" in
    *.tar.gz|*.tgz)   tar -xzf "$f" -C "$d/out" ;;
    *.tar.bz2|*.tbz)  tar -xjf "$f" -C "$d/out" ;;
    *.tar.xz|*.txz)   tar -xJf "$f" -C "$d/out" ;;
    *.zip)            unzip -qo "$f" -d "$d/out" ;;
    *)                place_bin "$f" "$1"; return ;;
  esac || return 1
  for b in "$@"; do
    p=$(find "$d/out" -type f -name "$b" -path "*bin/*" | head -1)
    [ -z "$p" ] && p=$(find "$d/out" -type f -name "$b" | head -1)
    [ -n "$p" ] || { echo "binary '$b' not found in archive"; return 1; }
    place_bin "$p" "$b" || return 1
  done
}
gh_install() {  # gh_install owner/repo "bin1 bin2" pattern...
  local repo=$1 bins=$2 url; shift 2
  url=$(gh_asset "$repo" "$@") || { echo "$url"; return 1; }
  # shellcheck disable=SC2086
  fetch_install "$url" $bins
}
MUSL_OR_GNU=('@ARCH@-unknown-linux-musl\.tar\.gz$' '@ARCH@-unknown-linux-gnu\.tar\.gz$')

tool_version() {  # prints installed version or nothing
  local id=$1 bin=${I_BIN[$1]} out
  [ "$bin" = "-" ] && return 1
  command -v "$bin" >/dev/null 2>&1 || return 1
  case "$id" in
    kubectl)   out=$(kubectl version --client 2>/dev/null) ;;
    helm)      out=$(helm version --short 2>/dev/null) ;;
    k9s)       out=$(k9s version --short 2>/dev/null) ;;
    tmux)      out=$(tmux -V 2>/dev/null) ;;
    ncdu)      out=$(ncdu -v 2>/dev/null) ;;
    terraform|opentofu) out=$("$bin" version 2>/dev/null | head -1) ;;
    azure|gcloud) echo "installed"; return 0 ;;   # slow to query
    *)         out=$(timeout 5 "$bin" --version 2>/dev/null </dev/null | head -3) ;;
  esac
  out=$(grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' <<<"$out" | head -1)
  echo "${out:-installed}"
}
state_has() { grep -qxF "$1" "$STATE_FILE" 2>/dev/null; }

# ──────────────────────────── installers ────────────────────────────
install_fzf()        { gh_install junegunn/fzf fzf 'linux_@ARCH@\.tar\.gz$'; }
install_zoxide()     { gh_install ajeetdsouza/zoxide zoxide "${MUSL_OR_GNU[@]}"; }
install_bat()        { gh_install sharkdp/bat bat "${MUSL_OR_GNU[@]}"; }
install_eza()        { gh_install eza-community/eza eza 'eza_@ARCH@-unknown-linux-musl\.tar\.gz$' 'eza_@ARCH@-unknown-linux-gnu\.tar\.gz$'; }
install_ripgrep()    { gh_install BurntSushi/ripgrep rg "${MUSL_OR_GNU[@]}"; }
install_fd()         { gh_install sharkdp/fd fd "${MUSL_OR_GNU[@]}"; }
install_jq()         { gh_install jqlang/jq jq 'jq-linux-@ARCH@$'; }
install_yq()         { gh_install mikefarah/yq yq 'yq_linux_@ARCH@$'; }
install_tldr()       { local u; u=$(gh_asset tealdeer-rs/tealdeer 'tealdeer-linux-@ARCH@-musl$') || u=$(gh_asset dbrgn/tealdeer 'tealdeer-linux-@ARCH@-musl$') || return 1
                       fetch_install "$u" tldr && { timeout 30 tldr --update >/dev/null 2>&1 || true; }; }
install_ncdu()       { pkg_install_epel ncdu; }
install_tmux()       { pkg_install tmux; }
install_htop()       { pkg_install_epel htop; }
install_delta()      { gh_install dandavison/delta delta "${MUSL_OR_GNU[@]}" || return 1
                       if command -v git >/dev/null; then
                         git config --global core.pager delta
                         git config --global interactive.diffFilter 'delta --color-only'
                         git config --global delta.navigate true
                         git config --global delta.line-numbers true
                         git config --global merge.conflictstyle zdiff3
                       fi; }
install_lazygit()    { gh_install jesseduffield/lazygit lazygit 'lazygit_.*_linux_@ARCH@\.tar\.gz$'; }
install_starship()   { gh_install starship/starship starship "${MUSL_OR_GNU[@]}" || return 1
                       mkdir -p "$HOME/.config"
                       [ -f "$HOME/.config/starship.toml" ] || starship preset plain-text-symbols -o "$HOME/.config/starship.toml" 2>/dev/null || true; }
install_btop()       { gh_install aristocratos/btop btop 'btop-@ARCH@-unknown-linux-musl\.tar\.gz$' 'btop-@ARCH@-.*linux-musl\.(tbz|tar\.gz)$'; }
install_fastfetch()  { gh_install fastfetch-cli/fastfetch fastfetch 'fastfetch-linux-@ARCH@\.tar\.gz$'; }

install_docker() {
  [ "$HAS_ROOT" = 1 ] || { echo "docker needs sudo/root"; return 1; }
  if [ "$PKG" = apt ]; then
    dl https://get.docker.com "$TMP/get-docker.sh" && $SUDO sh "$TMP/get-docker.sh" || return 1
  elif [ "$OS_ID" = amzn ]; then
    pkg_install docker || return 1
    local u; u=$(gh_asset docker/compose "docker-compose-linux-$ARCH_X$") || return 1
    $SUDO mkdir -p /usr/local/lib/docker/cli-plugins
    dl "$u" "$TMP/docker-compose" && $SUDO install -m 0755 "$TMP/docker-compose" /usr/local/lib/docker/cli-plugins/docker-compose
  else
    local repo=centos; [ "$OS_ID" = fedora ] && repo=fedora; [ "$OS_ID" = rhel ] && repo=rhel
    $SUDO $PKG install -y dnf-plugins-core yum-utils >/dev/null 2>&1 || true
    if command -v dnf >/dev/null; then
      $SUDO dnf config-manager --add-repo "https://download.docker.com/linux/$repo/docker-ce.repo" 2>/dev/null \
        || $SUDO dnf config-manager addrepo --from-repofile="https://download.docker.com/linux/$repo/docker-ce.repo"
    else
      $SUDO yum-config-manager --add-repo "https://download.docker.com/linux/$repo/docker-ce.repo"
    fi
    pkg_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || return 1
  fi
  $SUDO systemctl enable --now docker 2>/dev/null || true
  [ "$(id -u)" -ne 0 ] && $SUDO usermod -aG docker "$USER" && echo "added $USER to docker group (re-login to use without sudo)"
  return 0
}
install_kubectl() {
  local v; v=$(curl -fsSL https://dl.k8s.io/release/stable.txt) || return 1
  fetch_install "https://dl.k8s.io/release/$v/bin/linux/$ARCH/kubectl" kubectl
}
install_helm() {
  local t; t=$(gh_tag helm/helm) || return 1
  fetch_install "https://get.helm.sh/helm-$t-linux-$ARCH.tar.gz" helm
}
install_k9s()        { gh_install derailed/k9s k9s 'k9s_linux_@ARCH@\.tar\.gz$'; }
install_kubectx()    { gh_install ahmetb/kubectx kubectx 'kubectx_.*_linux_@ARCH@\.tar\.gz$' || return 1
                       gh_install ahmetb/kubectx kubens 'kubens_.*_linux_@ARCH@\.tar\.gz$'; }
install_stern()      { gh_install stern/stern stern 'stern_.*_linux_@ARCH@\.tar\.gz$'; }
install_sofka()      { gh_install nklmilojevic/sofka sofka "${MUSL_OR_GNU[@]}"; }
install_k3d()        { gh_install k3d-io/k3d k3d 'k3d-linux-@ARCH@$'; }
install_k3s() {
  [ "$HAS_ROOT" = 1 ] || { echo "k3s server needs sudo/root"; return 1; }
  local t="--traefik"; [ "$OPT_NO_TRAEFIK" = 1 ] && t="--no-traefik"
  "$TOOLBOX_HOME/bin/toolbox-k3s" create k3s --yes "$t"
}
install_lazydocker() { gh_install jesseduffield/lazydocker lazydocker 'lazydocker_.*_linux_@ARCH@\.tar\.gz$'; }
install_dive()       { gh_install wagoodman/dive dive 'dive_.*_linux_@ARCH@\.tar\.gz$'; }
install_terraform() {
  local v; v=$(curl -fsSL https://checkpoint-api.hashicorp.com/v1/check/terraform | grep -oE '"current_version":"[^"]+"' | cut -d'"' -f4) || return 1
  [ -n "$v" ] || { echo "could not resolve terraform version"; return 1; }
  fetch_install "https://releases.hashicorp.com/terraform/$v/terraform_${v}_linux_$ARCH.zip" terraform
}
install_opentofu()   { gh_install opentofu/opentofu tofu 'tofu_.*_linux_@ARCH@\.tar\.gz$'; }
venv_install() {  # venv_install <name> <pip-pkg> <bins...>  — user-level python install
  local name=$1 pkg=$2 venv="$TOOLBOX_HOME/venvs/$1" b; shift 2
  command -v python3 >/dev/null || { echo "python3 is required"; return 1; }
  python3 -m venv "$venv" || { echo "python3 venv module missing (install python3-venv)"; return 1; }
  "$venv/bin/pip" install -q --upgrade pip "$pkg" || return 1
  for b in "$@"; do ln -sf "$venv/bin/$b" "$HOME/.local/bin/$b"; echo "$HOME/.local/bin/$b" >> "$BINS_FILE"; done
}
install_ansible() {
  if [ "$HAS_ROOT" = 1 ]; then
    if [ "$PKG" = apt ]; then pkg_install ansible && return 0
    else pkg_install ansible-core && return 0; pkg_install_epel ansible && return 0; fi
  fi
  venv_install ansible ansible ansible ansible-playbook ansible-galaxy ansible-vault ansible-inventory ansible-doc ansible-config
}
install_awscli() {
  local d="$TMP/aws"; mkdir -p "$d"
  dl "https://awscli.amazonaws.com/awscli-exe-linux-$ARCH_X.zip" "$d/aws.zip" && unzip -qo "$d/aws.zip" -d "$d" || return 1
  if [ "$HAS_ROOT" = 1 ]; then $SUDO "$d/aws/install" --update
  else "$d/aws/install" --update -i "$HOME/.local/aws-cli" -b "$HOME/.local/bin"; fi
}
install_azure() {
  if [ "$HAS_ROOT" = 1 ] && [ "$PKG" = apt ]; then
    dl https://aka.ms/InstallAzureCLIDeb "$TMP/az.sh" && $SUDO bash "$TMP/az.sh"; return
  elif [ "$HAS_ROOT" = 1 ]; then
    $SUDO rpm --import https://packages.microsoft.com/keys/microsoft.asc
    printf '[azure-cli]\nname=Azure CLI\nbaseurl=https://packages.microsoft.com/yumrepos/azure-cli\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc\n' \
      | $SUDO tee /etc/yum.repos.d/azure-cli.repo >/dev/null
    pkg_install azure-cli; return
  fi
  venv_install azure azure-cli az
}
install_gcloud() {
  local base dest
  if [ "$HAS_ROOT" = 1 ]; then base=/opt; else base="$HOME/.local"; fi
  dest="$base/google-cloud-sdk"
  dl "https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-linux-$ARCH_X.tar.gz" "$TMP/gcloud.tgz" || return 1
  $SUDO rm -rf "$dest"; $SUDO mkdir -p "$base"; $SUDO tar -xzf "$TMP/gcloud.tgz" -C "$base" || return 1
  $SUDO "$dest/install.sh" --quiet --usage-reporting false --path-update false --command-completion false || return 1
  for b in gcloud gsutil bq; do $SUDO ln -sf "$dest/bin/$b" "$BIN_DIR/$b"; echo "$BIN_DIR/$b" >> "$BINS_FILE"; done
}
# shell items only record themselves; files are generated in write_shell_config
install_alias-general() { :; }; install_alias-git() { :; }; install_alias-k8s() { :; }; install_alias-docker() { :; }
install_dot-fzf() { :; }
tui_write() {  # tui_write <file> — writes stdin to file, backing up a user's own (non-toolbox) version first
  if [ -f "$1" ] && ! grep -q 'devops-toolbox' "$1"; then cp "$1" "$1.bak.$(date +%s)"; echo "backed up $1"; fi
  cat > "$1"
}
emit_status_script() {
  mkdir -p "$(dirname "$1")"
  cat > "$1" <<'STATUS_EOF'
#!/usr/bin/env bash
# devops-toolbox: right side of the tmux top bar (IP · load · mem · k8s context). Called every few seconds.
T=white; A=yellow; RL=grey
[ -f "$HOME/.devops-toolbox/tmux-colors" ] && . "$HOME/.devops-toolbox/tmux-colors"
ip=$(hostname -I 2>/dev/null | awk '{print $1}')
load=$(cut -d' ' -f1 /proc/loadavg 2>/dev/null)
mem=$(awk '/^MemTotal:/{t=$2} /^MemAvailable:/{a=$2} END{if (t) printf "%d%%", (t-a)*100/t}' /proc/meminfo 2>/dev/null)
kc=${KUBECONFIG%%:*}; [ -f "$kc" ] || kc="$HOME/.kube/config"
ctx=$(sed -n 's/^current-context:[[:space:]]*//p' "$kc" 2>/dev/null | tr -d '"' | head -1)
printf '#[fg=%s]%s #[fg=%s]│ #[fg=%s]load %s #[fg=%s]│ #[fg=%s]mem %s' "$T" "${ip:-?}" "$RL" "$T" "${load:-?}" "$RL" "$T" "${mem:-?}"
[ -n "$ctx" ] && printf ' #[fg=%s]│ #[fg=%s]⎈ %s' "$RL" "$A" "$ctx"
exit 0
STATUS_EOF
  chmod +x "$1"
}
install_tmux-bar() {
  command -v tmux >/dev/null || { echo "tmux is not installed: tick 'tmux' in CLI Utilities too"; return 1; }
  emit_status_script "$TOOLBOX_HOME/bin/toolbox-status"
  tb_sync_tui_skins init
  # make ~/.tmux.conf load the theme (the toolbox's own tmux.conf already does)
  touch "$HOME/.tmux.conf"
  grep -q 'devops-toolbox/tmux-theme.conf' "$HOME/.tmux.conf"     || printf '
# devops-toolbox: themed top bar
source-file -q ~/.devops-toolbox/tmux-theme.conf
' >> "$HOME/.tmux.conf"
  # validate: load the generated theme into a throwaway tmux server; fail on any tmux error
  local rc=0
  tmux -L tb-check -f /dev/null new-session -d 'sleep 10' || return 1
  tmux -L tb-check source-file "$HOME/.tmux.conf" || rc=1
  tmux -L tb-check kill-server 2>/dev/null
  return $rc
}
install_dot-k8s-tui() {
  local cfg="${XDG_CONFIG_HOME:-$HOME/.config}" k9 sf
  k9="${K9S_CONFIG_DIR:-$cfg/k9s}"; sf="$cfg/sofka"
  mkdir -p "$k9" "$sf"

  tui_write "$k9/plugins.yaml" <<'EOF'
# devops-toolbox k9s plugins — press the shortcut on a selected row
plugins:
  stern-logs:
    shortCut: Ctrl-L
    description: Logs (stern, all containers)
    scopes: [pods, deployments, statefulsets, daemonsets]
    command: stern
    background: false
    args: [--tail, "100", --context, $CONTEXT, -n, $NAMESPACE, $NAME]
  debug-netshoot:
    shortCut: Shift-D
    description: Debug container (netshoot)
    scopes: [containers]
    command: bash
    background: false
    confirm: true
    args: [-c, "kubectl debug -it --context $CONTEXT -n $NAMESPACE $POD --target=$NAME --image=nicolaka/netshoot:latest --profile=general -- bash"]
  dive-image:
    shortCut: Shift-I
    description: Inspect image layers (dive)
    scopes: [containers]
    command: dive
    background: false
    args: [$COL-IMAGE]
  ns-get-all:
    shortCut: Ctrl-G
    description: kubectl get all
    scopes: [namespaces]
    command: bash
    background: false
    args: [-c, "kubectl get all -n $NAME --context $CONTEXT | less -K"]
  watch-events:
    shortCut: Shift-E
    description: Watch events
    scopes: [pods, deployments]
    command: bash
    background: false
    args: [-c, "kubectl get events -n $NAMESPACE --context $CONTEXT --sort-by=.lastTimestamp -w"]
EOF

  tui_write "$k9/hotkeys.yaml" <<'EOF'
# devops-toolbox k9s hotkeys — jump straight to a view from anywhere
hotKeys:
  shift-0: { shortCut: Shift-0, description: Pods,          command: pods }
  shift-1: { shortCut: Shift-1, description: Deployments,   command: dp }
  shift-2: { shortCut: Shift-2, description: Services,      command: svc }
  shift-3: { shortCut: Shift-3, description: Ingresses,     command: ing }
  shift-4: { shortCut: Shift-4, description: Nodes,         command: no }
  shift-5: { shortCut: Shift-5, description: Events,        command: ev }
  shift-6: { shortCut: Shift-6, description: Helm releases, command: helm }
  shift-7: { shortCut: Shift-7, description: Namespaces,    command: ns }
EOF

  tui_write "$k9/aliases.yaml" <<'EOF'
# devops-toolbox k9s aliases — type :<alias> in k9s
aliases:
  dp: deployments
  sec: v1/secrets
  cm: configmaps
  jo: jobs
  cj: cronjobs
  crb: clusterrolebindings
  rb: rolebindings
  np: networkpolicies
  pvc: persistentvolumeclaims
EOF

  # point k9s at the toolbox skin
  if [ ! -f "$k9/config.yaml" ]; then
    printf '# devops-toolbox k9s config\nk9s:\n  ui:\n    skin: devops-toolbox\n' > "$k9/config.yaml"
  elif grep -qE '^[[:space:]]+skin:' "$k9/config.yaml"; then
    sed -i -E 's/^([[:space:]]+skin:).*/\1 devops-toolbox/' "$k9/config.yaml"
  else
    echo "k9s: add 'skin: devops-toolbox' under k9s.ui in $k9/config.yaml to use the toolbox skin"
  fi

  # sofka: seed aliases once, then (re)write the managed skin block
  if [ ! -f "$sf/config.toml" ]; then
    cat > "$sf/config.toml" <<'EOF'
# devops-toolbox sofka config — your own settings are safe here; only the marked skin block is managed.
# Top-level options (e.g. default_namespace = "kube-system") must go ABOVE the first [table].

[aliases]
dp = "deployments"
sec = "secrets"
cm = "configmaps"
jo = "jobs"
cj = "cronjobs"
EOF
  fi
  tb_sync_tui_skins init
}
install_dot-tmux() {
  if [ -f "$HOME/.tmux.conf" ] && ! grep -q 'devops-toolbox' "$HOME/.tmux.conf"; then
    cp "$HOME/.tmux.conf" "$HOME/.tmux.conf.bak.$(date +%s)"
  fi
  cat > "$HOME/.tmux.conf" <<'EOF'
# devops-toolbox tmux config
set -g mouse on
set -g history-limit 50000
set -g base-index 1
setw -g pane-base-index 1
set -g renumber-windows on
set -sg escape-time 10
set -g default-terminal "tmux-256color"
set -ag terminal-overrides ",xterm-256color:RGB"
# prefix: Ctrl-a (Ctrl-b still works as fallback)
set -g prefix C-a
set -g prefix2 C-b
bind C-a send-prefix
# splits keep the current path
bind | split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"
bind c new-window -c "#{pane_current_path}"
# vim-style pane movement + resize
bind h select-pane -L; bind j select-pane -D; bind k select-pane -U; bind l select-pane -R
bind -r H resize-pane -L 5; bind -r J resize-pane -D 5; bind -r K resize-pane -U 5; bind -r L resize-pane -R 5
bind r source-file ~/.tmux.conf \; display "tmux.conf reloaded"
setw -g mode-keys vi
# colours + sticky top status bar follow the toolbox theme (from the "tmux top bar" item)
source-file -q ~/.devops-toolbox/tmux-theme.conf
EOF
}

# ──────────────────────────── login banner ──────────────────────────
# Written to ~/.devops-toolbox/banner.sh and also sourced by this installer for its header.
emit_banner_sh() {
  cat > "$1" <<'BANNER_EOF'
# devops-toolbox banner + toolbox-help  (generated — re-run the installer to update)
# Define everything below WITHOUT alias expansion, so aliases like mv='mv -i' or cat='bat' can't leak into functions.
_tb_ea=$(shopt -p expand_aliases); shopt -u expand_aliases
tb__c() {  # tb__c R G B fallback-256  → foreground colour escape
  if [ "${TB_TRUECOLOR:-0}" = 1 ]; then printf '\e[38;2;%s;%s;%sm' "$1" "$2" "$3"; else printf '\e[38;5;%sm' "$4"; fi
}
TB_THEMES="ocean amber ice snow matrix sand lavender"
# Theme = 6 logo gradient stops (top→bottom), rule, text, welcome, accent.  Each: "R G B fallback256"
tb__theme() {
  case "$1" in
    amber)    echo "255 215 90 221|245 195 70 220|230 175 55 178|210 155 45 172|190 135 40 136|165 115 35 130|140 110 40 94|235 190 90 179|255 220 120 222|255 255 255 231" ;;
    ice)      echo "205 235 255 195|188 222 252 153|172 208 246 153|156 193 236 110|140 178 226 110|124 162 214 67|110 130 160 67|170 185 210 146|255 135 190 211|255 105 180 205" ;;
    snow)     echo "255 255 255 231|236 236 242 255|216 216 228 252|196 196 214 250|176 176 198 248|156 156 182 246|120 120 140 243|200 200 212 252|255 180 80 215|255 210 90 221" ;;
    matrix)   echo "130 255 130 120|95 240 95 83|65 225 65 77|45 200 45 40|32 175 32 34|22 150 22 28|30 140 30 28|80 250 80 83|180 255 120 155|255 255 255 231" ;;
    sand)     echo "245 225 200 224|230 210 185 223|215 195 170 181|200 180 155 180|185 165 140 138|170 150 125 137|140 115 90 95|215 195 165 180|255 130 80 209|255 160 90 215" ;;
    lavender) echo "167 120 235 135|157 128 232 141|146 137 228 140|134 147 224 104|122 157 220 110|110 167 216 74|98 190 125 72|139 233 160 114|139 233 160 114|189 147 249 141" ;;
    *)        echo "125 207 255 117|110 190 250 117|95 170 240 75|80 150 230 68|65 130 215 68|50 110 200 25|70 110 160 61|160 200 240 153|160 200 240 153|255 158 100 215" ;;  # ocean
  esac
}
tb__init() {
  case "${COLORTERM:-}" in truecolor|24bit) TB_TRUECOLOR=1 ;; *) TB_TRUECOLOR=0 ;; esac
  local spec i; spec=$(tb__theme "${DEVOPS_TOOLBOX_THEME:-ocean}")
  IFS='|' read -r -a TB_STOPS <<<"$spec"
  # shellcheck disable=SC2086
  { TB_SEP=$(tb__c ${TB_STOPS[6]}); TB_G=$(tb__c ${TB_STOPS[7]}); TB_W=$(tb__c ${TB_STOPS[8]}); TB_P=$(tb__c ${TB_STOPS[9]}); }
  TB_D=$'\e[2m'; TB_B=$'\e[1m'; TB_R=$'\e[0m'
  local w; w=$({ stty size </dev/tty; } 2>/dev/null | cut -d" " -f2); w=${w:-${COLUMNS:-80}}; [ "$w" -gt 78 ] && w=78; [ "$w" -lt 40 ] && w=40
  TB_LINE=$(printf '%*s' $((w - 2)) '' | tr ' ' '=')
}
tb_logo() {  # big gradient DEVOPS logo (55 cols)
  local rows=(
    "██████╗  ███████╗ ██╗   ██╗  ██████╗  ██████╗  ███████╗"
    "██╔══██╗ ██╔════╝ ██║   ██║ ██╔═══██╗ ██╔══██╗ ██╔════╝"
    "██║  ██║ █████╗   ██║   ██║ ██║   ██║ ██████╔╝ ███████╗"
    "██║  ██║ ██╔══╝   ╚██╗ ██╔╝ ██║   ██║ ██╔═══╝  ╚════██║"
    "██████╔╝ ███████╗  ╚████╔╝  ╚██████╔╝ ██║      ███████║"
    "╚═════╝  ╚══════╝   ╚═══╝    ╚═════╝  ╚═╝      ╚══════╝"
  )
  local i
  for i in 0 1 2 3 4 5; do
    # shellcheck disable=SC2086
    printf '  %s%s%s\n' "$(tb__c ${TB_STOPS[$i]})" "${rows[$i]}" "$TB_R"
  done
}
toolbox-theme() {  # preview / switch theme:  toolbox-theme [name]
  local t i f="$HOME/.devops-toolbox/custom.sh"
  if [ -z "$1" ]; then
    for t in $TB_THEMES; do
      DEVOPS_TOOLBOX_THEME=$t tb__init
      printf '  %s%-9s%s ' "$TB_B" "$t" "$TB_R"
      for i in 0 1 2 3 4 5; do printf '%s██' "$(tb__c ${TB_STOPS[$i]})"; done
      printf ' %stext%s %swelcome%s %s%shelp%s\n' "$TB_G" "$TB_R" "$TB_W" "$TB_R" "$TB_P" "$TB_B" "$TB_R"
    done
    printf '\n  current: %s · switch: toolbox-theme <name>\n' "${DEVOPS_TOOLBOX_THEME:-ocean}"
    return
  fi
  case " $TB_THEMES " in *" $1 "*) ;; *) echo "unknown theme '$1' (choose: $TB_THEMES)"; return 1 ;; esac
  touch "$f"; sed -i '/^export DEVOPS_TOOLBOX_THEME=/d' "$f"
  echo "export DEVOPS_TOOLBOX_THEME=$1" >> "$f"
  export DEVOPS_TOOLBOX_THEME=$1
  tb_sync_tui_skins
  tb_banner
}

# ── k9s / sofka skins that follow the toolbox theme ──
tb__hex() { printf '#%02x%02x%02x' "$1" "$2" "$3"; }
tb_sync_tui_skins() {  # tb_sync_tui_skins [init]  — without "init", only refreshes skins the toolbox already manages
  local mode=${1:-update} theme=${DEVOPS_TOOLBOX_THEME:-ocean} s P M D RL T W A
  IFS='|' read -r -a s <<<"$(tb__theme "$theme")"
  # shellcheck disable=SC2086
  { P=$(tb__hex ${s[0]}); M=$(tb__hex ${s[3]}); D=$(tb__hex ${s[5]}); RL=$(tb__hex ${s[6]})
    T=$(tb__hex ${s[7]}); W=$(tb__hex ${s[8]}); A=$(tb__hex ${s[9]}); }
  local cfg="${XDG_CONFIG_HOME:-$HOME/.config}"
  local k9="${K9S_CONFIG_DIR:-$cfg/k9s}"

  if [ -f "$k9/skins/devops-toolbox.yaml" ] || { [ "$mode" = init ] && command -v k9s >/dev/null 2>&1; }; then
    mkdir -p "$k9/skins"
    cat > "$k9/skins/devops-toolbox.yaml" <<K9S_EOF
# devops-toolbox k9s skin — theme: $theme (regenerated by: toolbox-theme <name>)
k9s:
  body: { fgColor: "$T", bgColor: default, logoColor: "$P" }
  prompt: { fgColor: "$T", bgColor: default, suggestColor: "$RL" }
  info: { fgColor: "$A", sectionColor: "$T" }
  dialog:
    fgColor: "$T"
    bgColor: default
    buttonFgColor: "$T"
    buttonBgColor: "$D"
    buttonFocusFgColor: "#0b0f17"
    buttonFocusBgColor: "$A"
    labelFgColor: "$A"
    fieldFgColor: "$T"
  frame:
    border: { fgColor: "$RL", focusColor: "$P" }
    menu: { fgColor: "$T", keyColor: "$A", numKeyColor: "$A" }
    crumbs: { fgColor: "#0b0f17", bgColor: "$M", activeColor: "$A" }
    status:
      newColor: "$P"
      modifyColor: "$W"
      addColor: "#9ece6a"
      errorColor: "#f7768e"
      highlightColor: "$A"
      killColor: "$RL"
      completedColor: "$RL"
    title: { fgColor: "$T", bgColor: default, highlightColor: "$A", counterColor: "$P", filterColor: "$W" }
  views:
    charts:
      bgColor: default
      defaultDialColors: ["$P", "#f7768e"]
      defaultChartColors: ["$P", "#f7768e"]
    table:
      fgColor: "$T"
      bgColor: default
      cursorFgColor: "#0b0f17"
      cursorBgColor: "$M"
      markColor: "$A"
      header: { fgColor: "$P", bgColor: default, sorterColor: "$A" }
    xray: { fgColor: "$T", bgColor: default, cursorColor: "$M", graphicColor: "$P", showIcons: false }
    yaml: { keyColor: "$P", colonColor: "$RL", valueColor: "$T" }
    logs:
      fgColor: "$T"
      bgColor: default
      indicator: { fgColor: "$A", bgColor: default }
K9S_EOF
  fi

  local tt="$HOME/.devops-toolbox/tmux-theme.conf"
  if [ -f "$tt" ] || { [ "$mode" = init ] && command -v tmux >/dev/null 2>&1; }; then
    mkdir -p "$HOME/.devops-toolbox"
    printf 'T="%s"
A="%s"
RL="%s"
' "$T" "$A" "$RL" > "$HOME/.devops-toolbox/tmux-colors"
    cat > "$tt" <<TMUX_EOF
# devops-toolbox tmux theme: $theme  (regenerated by: toolbox-theme <name>)
set -g status on
set -g status-position top
set -g status-interval 5
set -g status-justify left
set -g status-style "bg=default,fg=$T"
set -g status-left-length 60
set -g status-right-length 140
set -g status-left "#[bg=$P,fg=#0b0f17,bold] DEVOPS #[bg=default,fg=$P,bold] #h #[fg=$RL,nobold]│ "
set -g status-right "#(\$HOME/.devops-toolbox/bin/toolbox-status) #[fg=$RL]│ #[fg=$P]%H:%M "
setw -g window-status-format "#[fg=$RL] #I:#W "
setw -g window-status-current-format "#[bg=$M,fg=#0b0f17,bold] #I:#W "
setw -g window-status-separator ""
set -g pane-border-style "fg=$RL"
set -g pane-active-border-style "fg=$P"
set -g message-style "bg=$D,fg=#ffffff"
set -g mode-style "bg=$M,fg=#0b0f17"
TMUX_EOF
    command -v tmux >/dev/null 2>&1 && tmux source-file "$tt" >/dev/null 2>&1
  fi

  local sf="$cfg/sofka/config.toml" skin extra=""
  case "$theme" in
    amber) skin=gruvbox-dark ;; ice) skin=nord ;; snow) skin=one-dark ;; sand) skin=flexoki-dark ;;
    lavender) skin=dracula ;;
    matrix) skin=monokai
            extra=$'[skin.colors]\nblue = "#50fa50"\nsky = "#7cff7c"\nsapphire = "#3cd23c"\nlavender = "#9cff9c"\nmauve = "#50fa50"\ntext = "#b4ffb4"\n' ;;
    *) skin=tokyo-night ;;
  esac
  if grep -q '^# >>> devops-toolbox skin' "$sf" 2>/dev/null || { [ "$mode" = init ] && command -v sofka >/dev/null 2>&1; }; then
    mkdir -p "${sf%/*}"; touch "$sf"
    awk '/^# >>> devops-toolbox skin/{skip=1} !skip{print} /^# <<< devops-toolbox skin/{skip=0}' "$sf" > "$sf.tmp" && mv "$sf.tmp" "$sf"
    if grep -q '^\[skin\]' "$sf"; then
      echo "sofka: your config.toml already has its own [skin]; leaving it alone" >&2
    else
      printf '# >>> devops-toolbox skin (follows toolbox-theme; delete this block to pick your own)\n[skin]\nname = "%s"\n%s# <<< devops-toolbox skin\n' "$skin" "$extra" >> "$sf"
    fi
  fi
  return 0
}
tb_tag() {  # right-aligned small tag under the logo, like "© 2026 user@host"
  local text="$1" pad
  pad=$(( 57 - ${#text} )); [ "$pad" -lt 2 ] && pad=2
  printf '%*s%s%s%s\n' "$pad" '' "$TB_D" "$text" "$TB_R"
}
tb_rule() { printf '  %s%s%s\n' "$TB_SEP" "$TB_LINE" "$TB_R"; }
tb_text() { printf '  %s%s%s\n' "$TB_G" "$*" "$TB_R"; }

tb_banner() {
  tb__init
  local host user kernel up s d h m shell os arch cpus load mem disk ip extra=""
  host=${HOSTNAME%%.*}; user=${USER:-$(id -un)}
  kernel=$(uname -r | cut -d- -f1); arch=$(uname -m)
  s=$(cut -d. -f1 /proc/uptime 2>/dev/null || echo 0)
  d=$((s / 86400)); h=$((s % 86400 / 3600)); m=$((s % 3600 / 60))
  up="$d day$([ "$d" = 1 ] || echo s); $h hour$([ "$h" = 1 ] || echo s); $m min"
  shell="Bash ${BASH_VERSINFO[0]}.${BASH_VERSINFO[1]}"
  os=$( . /etc/os-release 2>/dev/null; echo "${PRETTY_NAME:-Linux}")
  cpus=$(nproc 2>/dev/null || echo "?"); load=$(cut -d' ' -f1-3 /proc/loadavg 2>/dev/null)
  mem=$(awk '/^MemTotal:/ {t=$2} /^MemAvailable:/ {a=$2} END {if (t) printf "%.1fG/%.1fG", (t-a)/1048576, t/1048576}' /proc/meminfo 2>/dev/null)
  disk=$(df -h / 2>/dev/null | awk 'NR==2 {print $3 "/" $2 " (" $5 ")"}')
  ip=$(hostname -I 2>/dev/null | awk '{print $1}')
  [ -n "$ip" ] || ip=$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<NF;i++) if($i=="src"){print $(i+1); exit}}')
  if command -v docker >/dev/null 2>&1 && [ -r /var/run/docker.sock ] && [ -w /var/run/docker.sock ]; then
    extra+="Docker: $(timeout 2 docker ps -q 2>/dev/null | wc -l) running; "
  fi
  if command -v kubectl >/dev/null 2>&1; then
    extra+="K8s: $(timeout 2 kubectl config current-context 2>/dev/null || echo none); "
  fi

  echo
  tb_logo
  tb_tag "© $(date +%Y) $user@$host"
  tb_rule
  tb_text "System Information: Kernel: $kernel; Uptime: $up; Shell: $shell"
  tb_rule
  tb_text "$os * $arch * $cpus CPU * Load: $load"
  tb_text "Memory: ${mem:-?}; Disk(/): ${disk:-?}; IP: ${ip:-?}"
  [ -n "$extra" ] && tb_text "${extra%; }"
  tb_rule
  echo
  printf '  %sWelcome to %s%s%s%s, %s! Your DevOps toolbox is ready.%s\n' "$TB_W" "$TB_B" "$host" "$TB_R" "$TB_W" "$user" "$TB_R"
  printf "  %sTo get a list of toolbox commands, type %s'toolbox-help'%s%s.%s\n\n" "$TB_W" "$TB_P$TB_B" "$TB_R" "$TB_W" "$TB_R"
}

_tb_s() { printf '\n  %s%s%s%s\n' "$TB_P" "$TB_B" "$1" "$TB_R"; }
_tb_h() { printf '    %s%-26s%s %s%s%s\n' "$TB_G" "$1" "$TB_R" "$TB_D" "$2" "$TB_R"; }
_tb_has() { command -v "$1" >/dev/null 2>&1 || alias "$1" >/dev/null 2>&1 || declare -F "$1" >/dev/null 2>&1; }
toolbox-help() {
  tb__init
  echo; tb_rule; tb_text "DevOps Toolbox — commands available on this machine"; tb_rule
  _tb_s "Navigation & files"
  _tb_has z      && _tb_h "z <dir>" "jump to a frequently used directory (zi = interactive)"
  _tb_has ll     && _tb_h "ll / la / lt" "long list / all / tree view"
  _tb_has mkcd   && _tb_h "mkcd <dir>" "make a directory and cd into it"
  _tb_has extract && _tb_h "extract <file>" "unpack any archive"
  _tb_has bat    && _tb_h "cat / bcat" "syntax-highlighted file view"
  _tb_s "Search"
  _tb_has fzf    && _tb_h "Ctrl-R / Ctrl-T" "fuzzy history / fuzzy file picker (Alt-C: cd)"
  _tb_has fe     && _tb_h "fe / fkill / fh" "fuzzy edit file / kill process / rerun history"
  _tb_has rg     && _tb_h "rg <text>" "ripgrep: search file contents"
  _tb_has fd     && _tb_h "fd <name>" "find files by name"
  if _tb_has gs; then
    _tb_s "Git"
    _tb_h "gs / gd / gds" "status / diff / staged diff"
    _tb_h "ga / gaa / gc \"m\"" "add / add all / commit"
    _tb_h "gp / gpl / gf" "push / pull --rebase / fetch --prune"
    _tb_h "gl / gla / gco" "graph log / all branches / checkout"
    _tb_has lg && _tb_h "lg" "lazygit"
  fi
  if _tb_has k; then
    _tb_s "Kubernetes"
    _tb_h "k" "kubectl (with tab completion)"
    _tb_h "kgp / kgpa / kgpw" "pods / all namespaces / wide"
    _tb_h "kgs / kgd / kgn / kge" "services / deployments / nodes / events"
    _tb_h "kl / kex / kpf" "logs -f / exec -it / port-forward"
    _tb_h "kaf / kdel / krr" "apply -f / delete / rollout restart"
    _tb_h "kns / kctx" "switch namespace / context"
    _tb_has k9s && _tb_h "k9s" "Kubernetes TUI"
    _tb_has stern && _tb_h "stern <pod>" "tail logs from many pods"
    _tb_has sofka && _tb_h "sofka (sf)" "Rust Kubernetes TUI; :skin, :ctx, sofka import k9s"
  fi
  if _tb_has k9s && [ -f "${K9S_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/k9s}/hotkeys.yaml" ]; then
    _tb_s "Inside k9s"
    _tb_h ":pod :dp :svc :ns" "jump to a view (also :sec :cm :jo :cj :np :pvc)"
    _tb_h "Shift-0 ... Shift-7" "pods / deploy / svc / ingress / nodes / events / helm / ns"
    _tb_h "Ctrl-L" "stern logs for the selected pod or workload"
    _tb_h "Shift-D / Shift-I" "debug container (netshoot) / dive image (containers view)"
    _tb_h "Shift-E / Ctrl-G" "watch events / kubectl get all (namespaces view)"
    _tb_h "l / s / d / e" "logs / shell / describe / edit"
    _tb_h "Shift-F / x / Ctrl-D" "port-forward / decode secret / delete"
    _tb_h "/ ? :q" "filter / all keys / quit"
  fi
  if _tb_has dps; then
    _tb_s "Docker"
    _tb_h "dps / dpsa / di" "containers / all / images"
    _tb_h "dex / dlog" "exec -it / logs -f"
    _tb_h "dc / dcu / dcd / dcl" "compose / up -d / down / logs"
    _tb_h "dprune" "remove everything unused"
    _tb_has ld && _tb_h "ld" "lazydocker"
  fi
  if _tb_has toolbox-k3s && { _tb_has k3d || _tb_has k3s; }; then
    _tb_s "Clusters (k3s / k3d)"
    _tb_h "toolbox-k3s" "interactive menu: create / join / status / delete"
    _tb_h "toolbox-k3s create k3d dev" "k3s-in-Docker cluster (--agents N, --no-traefik)"
    _tb_h "toolbox-k3s create k3s" "real k3s server on this machine"
    _tb_h "toolbox-k3s token" "join command for worker machines"
    _tb_h "toolbox-k3s status" "clusters, contexts and nodes"
  fi
  if [ -f "$HOME/.devops-toolbox/tmux-theme.conf" ] && _tb_has tmux; then
    _tb_s "tmux (top bar)"
    _tb_h "Ctrl-a  then  d" "detach (work keeps running; ssh back in to resume)"
    _tb_h "Ctrl-a  c / n / p" "new window / next / previous"
    _tb_h "Ctrl-a  | / -" "split side-by-side / top-bottom"
    _tb_h "Ctrl-a  h j k l" "move between panes (H J K L resize)"
    _tb_h "Ctrl-a  [" "scroll / copy mode (q to leave)"
    _tb_h "DEVOPS_TOOLBOX_TMUX=0" "turn off auto-tmux on SSH (in custom.sh)"
  fi
  _tb_s "Monitoring"
  _tb_has btop  && _tb_h "btop (top)" "resource monitor"
  _tb_has htop  && _tb_h "htop" "process viewer"
  _tb_has ncdu  && _tb_h "ncdu /" "disk usage explorer"
  _tb_has ports && _tb_h "ports / myip" "listening ports / public IP"
  _tb_has fastfetch && _tb_h "fastfetch" "detailed system info"
  _tb_s "Toolbox"
  _tb_h "toolbox-banner" "show the welcome banner again"
  _tb_h "toolbox-theme [name]" "preview / switch banner colours"
  _tb_h "toolbox-help" "this screen"
  _tb_h "~/.devops-toolbox/custom.sh" "your own aliases (never overwritten)"
  _tb_h "DEVOPS_TOOLBOX_BANNER" "1 = this banner, fastfetch, 0 = off"
  echo
}
alias toolbox-banner='tb_banner'
eval "$_tb_ea"; unset _tb_ea
BANNER_EOF
}

# ──────────────────────────── toolbox-k3s helper ────────────────────
emit_k3s_helper() {
  mkdir -p "$(dirname "$1")"
  cat > "$1" <<'K3S_EOF'
#!/usr/bin/env bash
# toolbox-k3s — create, join and manage k3s / k3d clusters (devops-toolbox)
set -o pipefail
if [ -t 1 ]; then C=$'\e[36m'; G=$'\e[32m'; Y=$'\e[33m'; RED=$'\e[31m'; B=$'\e[1m'; D=$'\e[2m'; R=$'\e[0m'
else C=; G=; Y=; RED=; B=; D=; R=; fi
ok()   { printf "  ${G}✔${R} %s\n" "$*"; }
info() { printf "  ${C}➜${R} %s\n" "$*"; }
warn() { printf "  ${Y}⚠${R} %s\n" "$*"; }
die()  { printf "  ${RED}✖${R} %s\n" "$*" >&2; exit 1; }

YES=0; NO_TRAEFIK=""; AGENTS=""
SUDO=""; [ "$(id -u)" -ne 0 ] && SUDO=sudo
KCFG="$HOME/.kube/config"
TOKEN_FILE=/var/lib/rancher/k3s/server/node-token

usage() {
  cat <<EOF

  ${B}toolbox-k3s${R} — k3s & k3d clusters

  ${B}Interactive${R}
    toolbox-k3s                         menu

  ${B}k3s (real cluster on this machine, systemd)${R}
    toolbox-k3s create k3s [--no-traefik]     install a k3s server here
    toolbox-k3s token                         show the join command for workers
    toolbox-k3s join <https://ip:6443> <token>  join THIS machine as a worker
    toolbox-k3s delete k3s                    uninstall k3s (server or agent)

  ${B}k3d (k3s in Docker, for testing)${R}
    toolbox-k3s create k3d [name] [--agents N] [--no-traefik]
    toolbox-k3s delete k3d [name]

  ${B}Both${R}
    toolbox-k3s status                  what's running + nodes
    toolbox-k3s kubeconfig              re-copy the k3s kubeconfig into ~/.kube/config

  ${D}-y / --yes accepts defaults without asking.${R}

EOF
}

ask() {  # ask "question" y|n  → returns 0 for yes
  local def=${2:-n} a
  if [ "$YES" = 1 ] || [ ! -r /dev/tty ]; then [ "$def" = y ]; return; fi
  printf "  ${C}?${R} %s ${D}[%s]${R} " "$1" "$([ "$def" = y ] && echo Y/n || echo y/N)"
  IFS= read -r a </dev/tty || a=""
  a=${a:-$def}; [[ "$a" =~ ^[Yy] ]]
}
confirm() {  # confirm "question" — destructive actions: --yes means YES
  [ "$YES" = 1 ] && return 0
  [ -r /dev/tty ] || return 1
  ask "$1" n
}
ask_value() {  # ask_value "question" default → prints answer
  local a
  if [ "$YES" = 1 ] || [ ! -r /dev/tty ]; then echo "$2"; return; fi
  printf "  ${C}?${R} %s ${D}[%s]${R} " "$1" "$2" >&2
  IFS= read -r a </dev/tty || a=""
  echo "${a:-$2}"
}
need_sudo() { [ -z "$SUDO" ] || sudo -n true 2>/dev/null || sudo -v || die "This needs sudo/root."; }
private_ip() { hostname -I 2>/dev/null | awk '{print $1}'; }

merge_kubeconfig() {  # merge_kubeconfig <file> <name> — adds/replaces context <name> in ~/.kube/config
  local src=$1 name=$2 tmp
  command -v kubectl >/dev/null || { warn "kubectl not found; kubeconfig left at $src"; return 1; }
  tmp=$(mktemp)
  sed -E "s/^([[:space:]-]*(name|cluster|user|current-context):) default$/\1 $name/" "$src" > "$tmp"
  mkdir -p "$HOME/.kube"; chmod 700 "$HOME/.kube"
  if [ -s "$KCFG" ]; then
    cp "$KCFG" "$KCFG.bak.$(date +%s)"
    kubectl --kubeconfig "$KCFG" config delete-context "$name" >/dev/null 2>&1
    kubectl --kubeconfig "$KCFG" config delete-cluster "$name" >/dev/null 2>&1
    kubectl --kubeconfig "$KCFG" config delete-user    "$name" >/dev/null 2>&1
    KUBECONFIG="$KCFG:$tmp" kubectl config view --flatten > "$tmp.merged" && command mv -f "$tmp.merged" "$KCFG"
  else
    command cp -f "$tmp" "$KCFG"
  fi
  chmod 600 "$KCFG"; rm -f "$tmp"
  kubectl config use-context "$name" >/dev/null && ok "kubeconfig: context '$name' added to ~/.kube/config and selected (backup kept)"
}

k3s_kubeconfig() {
  $SUDO test -f /etc/rancher/k3s/k3s.yaml || die "No k3s server on this machine."
  local f; f=$(mktemp)
  $SUDO cat /etc/rancher/k3s/k3s.yaml > "$f" && merge_kubeconfig "$f" "k3s-$(hostname -s)"
  rm -f "$f"
}

show_join() {
  need_sudo
  $SUDO test -f "$TOKEN_FILE" || die "No k3s server on this machine (run: toolbox-k3s create k3s)."
  local token ip pub imds
  token=$($SUDO cat "$TOKEN_FILE"); ip=$(private_ip)
  imds=$(curl -s -X PUT --max-time 2 http://169.254.169.254/latest/api/token -H 'X-aws-ec2-metadata-token-ttl-seconds: 60' 2>/dev/null)
  [ -n "$imds" ] && pub=$(curl -s --max-time 2 -H "X-aws-ec2-metadata-token: $imds" http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null)
  printf "\n  ${B}Join another machine as a worker${R}  ${D}(run this ON the new machine)${R}\n\n"
  printf "    ${G}toolbox-k3s join https://%s:6443 %s${R}\n\n" "$ip" "$token"
  printf "  ${D}Without the toolbox:${R}\n    curl -sfL https://get.k3s.io | K3S_URL=https://%s:6443 K3S_TOKEN=%s sh -\n\n" "$ip" "$token"
  printf "  ${Y}Network:${R} workers must reach this server on ${B}TCP 6443${R}; all nodes need ${B}UDP 8472${R} (flannel) and ${B}TCP 10250${R} between them.\n"
  printf "  ${D}On AWS, allow those ports in the security group from the same SG or the VPC CIDR, and use the private IP (%s)%s.${R}\n\n" \
    "$ip" "${pub:+. Public IP: $pub (only if workers are outside the VPC)}"
}

create_k3s() {
  need_sudo
  if systemctl is-active --quiet k3s 2>/dev/null; then
    warn "A k3s server is already running here; refreshing kubeconfig only."
  else
    systemctl is-active --quiet k3s-agent 2>/dev/null && die "This machine is a k3s worker. Run 'toolbox-k3s delete k3s' first."
    if [ -z "$NO_TRAEFIK" ]; then
      if ask "Disable the built-in Traefik ingress? (yes if you'll use nginx-ingress etc.)" n; then NO_TRAEFIK=1; else NO_TRAEFIK=0; fi
    fi
    local exec_args="server --write-kubeconfig-mode 600"
    [ "$NO_TRAEFIK" = 1 ] && exec_args+=" --disable traefik"
    info "Installing k3s: $exec_args"
    curl -sfL https://get.k3s.io | $SUDO env INSTALL_K3S_EXEC="$exec_args" sh - || die "k3s install failed."
  fi
  info "Waiting for the node to become Ready…"
  local i ready=0
  for i in $(seq 1 60); do   # up to ~3 minutes; the node object appears a few seconds after install
    if $SUDO k3s kubectl get nodes --no-headers 2>/dev/null | grep -q ' Ready '; then ready=1; break; fi
    sleep 3
  done
  [ "$ready" = 1 ] && ok "Node is Ready." || warn "Node not Ready yet. Check with: sudo k3s kubectl get nodes"
  k3s_kubeconfig
  kubectl get nodes -o wide 2>/dev/null | sed 's/^/    /'
  if [ "$YES" = 1 ]; then
    info "To add worker machines, run 'toolbox-k3s token' here (prints the join command)."
  else
    show_join
  fi
}

join_k3s() {
  local url=$1 token=$2
  need_sudo
  systemctl is-active --quiet k3s 2>/dev/null && die "This machine is already a k3s server."
  [ -n "$url" ]   || url=$(ask_value "Server URL" "https://<server-private-ip>:6443")
  [ -n "$token" ] || token=$(ask_value "Join token (from 'toolbox-k3s token' on the server)" "")
  [[ "$url" == https://*:6443 ]] && [[ "$url" != *"<"* ]] && [ -n "$token" ] \
    || die "Usage: toolbox-k3s join https://<server-ip>:6443 <token>"
  info "Checking the server is reachable…"
  curl -sk --max-time 5 "$url/ping" >/dev/null 2>&1 || warn "Could not reach $url. Check the security group allows TCP 6443 from this machine."
  curl -sfL https://get.k3s.io | $SUDO env K3S_URL="$url" K3S_TOKEN="$token" sh - || die "k3s agent install failed."
  ok "Joined as a worker. On the server run: kubectl get nodes"
}

k3d_run() {  # k3d with Docker access, even right after being added to the docker group
  command -v docker >/dev/null || die "Docker is required for k3d (tick 'docker' in the toolbox menu)."
  if docker info >/dev/null 2>&1; then k3d "$@"
  elif id -nG "$USER" 2>/dev/null | grep -qw docker; then sg docker -c "$(printf '%q ' k3d "$@")"
  else die "No permission to use Docker. Run: sudo usermod -aG docker $USER, then log out and back in."; fi
}

create_k3d() {
  command -v k3d >/dev/null || die "k3d is not installed (re-run the toolbox installer and tick k3d)."
  local name=$1 agents=$AGENTS
  [ -n "$name" ]   || name=$(ask_value "Cluster name" "dev")
  [ -n "$agents" ] || agents=$(ask_value "Number of worker (agent) nodes" "2")
  [[ "$agents" =~ ^[0-9]+$ ]] || die "Agents must be a number."
  if [ -z "$NO_TRAEFIK" ]; then
    if ask "Disable the built-in Traefik ingress?" n; then NO_TRAEFIK=1; else NO_TRAEFIK=0; fi
  fi
  local args=(cluster create "$name" --agents "$agents" --wait --timeout 300s
              --kubeconfig-update-default --kubeconfig-switch-context)
  [ "$NO_TRAEFIK" = 1 ] && args+=(--k3s-arg "--disable=traefik@server:*")
  info "Creating k3d cluster '$name' (1 server + $agents agents)…"
  k3d_run "${args[@]}" || die "k3d cluster create failed."
  chmod 600 "$KCFG" 2>/dev/null
  ok "Cluster ready, kubectl context: k3d-$name"
  kubectl get nodes 2>/dev/null | sed 's/^/    /'
}

delete_k3d() {
  local name=$1
  [ -n "$name" ] || { k3d_run cluster list; name=$(ask_value "Cluster to delete" "dev"); }
  confirm "Delete k3d cluster '$name'?" || exit 0
  k3d_run cluster delete "$name"
}

delete_k3s() {
  need_sudo
  local s=""
  [ -x /usr/local/bin/k3s-uninstall.sh ] && s=/usr/local/bin/k3s-uninstall.sh
  [ -x /usr/local/bin/k3s-agent-uninstall.sh ] && s=/usr/local/bin/k3s-agent-uninstall.sh
  [ -n "$s" ] || die "k3s is not installed on this machine."
  confirm "Uninstall k3s from this machine? All workloads on it are deleted." || exit 0
  $SUDO "$s"
  if command -v kubectl >/dev/null && [ -s "$KCFG" ]; then
    local n="k3s-$(hostname -s)" was other
    was=$(kubectl config current-context 2>/dev/null)
    kubectl config delete-context "$n" >/dev/null 2>&1; kubectl config delete-cluster "$n" >/dev/null 2>&1
    kubectl config delete-user "$n" >/dev/null 2>&1
    if [ "$was" = "$n" ]; then   # don't leave kubectl pointing at a deleted cluster
      other=$(kubectl config get-contexts -o name 2>/dev/null | head -1)
      if [ -n "$other" ]; then kubectl config use-context "$other" >/dev/null && info "kubectl context switched to '$other'"
      else kubectl config unset current-context >/dev/null 2>&1; fi
    fi
  fi
  ok "k3s removed."
}

status() {
  printf "\n  ${B}k3s${R}\n"
  if systemctl is-active --quiet k3s 2>/dev/null; then ok "server running ($(k3s --version 2>/dev/null | head -1 | awk '{print $3}'))"
  elif systemctl is-active --quiet k3s-agent 2>/dev/null; then ok "agent (worker) running"
  else info "not running on this machine"; fi
  printf "\n  ${B}k3d${R}\n"
  if command -v k3d >/dev/null; then k3d_run cluster list 2>&1 | sed 's/^/    /'; else info "k3d not installed"; fi
  printf "\n  ${B}kubectl${R}\n"
  if command -v kubectl >/dev/null && [ -s "$KCFG" ]; then
    info "current context: $(kubectl config current-context 2>/dev/null)"
    kubectl get nodes 2>&1 | sed 's/^/    /'
  else info "no kubeconfig yet"; fi
  echo
}

menu() {
  local c
  while true; do
    printf "\n  ${C}${B}toolbox-k3s${R} ${D}· k3s & k3d clusters${R}\n  ${D}──────────────────────────────────────────────────${R}\n"
    printf "   ${B}1${R}) Create k3s server on THIS machine  ${D}(systemd, survives reboots)${R}\n"
    printf "   ${B}2${R}) Show join command for workers\n"
    printf "   ${B}3${R}) Join THIS machine to a k3s server  ${D}(worker)${R}\n"
    printf "   ${B}4${R}) Create k3d cluster                 ${D}(k3s in Docker, multi-node)${R}\n"
    printf "   ${B}5${R}) Delete k3d cluster\n"
    printf "   ${B}6${R}) Status\n"
    printf "   ${B}7${R}) Uninstall k3s from this machine\n"
    printf "   ${B}q${R}) Quit\n\n  Choice: "
    IFS= read -r c </dev/tty || exit 0
    case "$c" in
      1) ( create_k3s ) ;; 2) ( show_join ) ;; 3) ( join_k3s ) ;; 4) ( create_k3d ) ;;
      5) ( delete_k3d ) ;; 6) ( status ) ;; 7) ( delete_k3s ) ;; q|Q|"") exit 0 ;;
      *) warn "Unknown choice: $c" ;;
    esac
  done
}

cmd=${1:-menu}; [ $# -gt 0 ] && shift
ARGS=()
while [ $# -gt 0 ]; do
  case "$1" in
    -y|--yes) YES=1 ;;
    --no-traefik) NO_TRAEFIK=1 ;;
    --traefik) NO_TRAEFIK=0 ;;
    --agents) AGENTS=$2; shift ;;
    --agents=*) AGENTS=${1#*=} ;;
    *) ARGS+=("$1") ;;
  esac
  shift
done
case "$cmd" in
  menu)        [ -r /dev/tty ] || { usage; exit 1; }; menu ;;
  create)      case "${ARGS[0]}" in k3s) create_k3s ;; k3d) create_k3d "${ARGS[1]}" ;; *) die "Usage: toolbox-k3s create k3s|k3d [name]" ;; esac ;;
  join)        join_k3s "${ARGS[0]}" "${ARGS[1]}" ;;
  token|join-cmd) show_join ;;
  delete)      case "${ARGS[0]}" in k3s) delete_k3s ;; k3d) delete_k3d "${ARGS[1]}" ;; *) die "Usage: toolbox-k3s delete k3s|k3d [name]" ;; esac ;;
  status|list) status ;;
  kubeconfig)  need_sudo; k3s_kubeconfig ;;
  -h|--help|help) usage ;;
  *) usage; exit 1 ;;
esac
K3S_EOF
  chmod +x "$1"
}

# ──────────────────────────── shell config ──────────────────────────
write_fastfetch_config() {
  local cfg="$HOME/.config/fastfetch"; mkdir -p "$cfg"
  cat > "$cfg/devops-logo.txt" <<'EOF'
$1  ██████╗ ███████╗██╗   ██╗
$1  ██╔══██╗██╔════╝██║   ██║
$1  ██║  ██║█████╗  ██║   ██║
$1  ██║  ██║██╔══╝  ╚██╗ ██╔╝
$1  ██████╔╝███████╗ ╚████╔╝
$1  ╚═════╝ ╚══════╝  ╚═══╝
$2   ██████╗ ██████╗ ███████╗
$2  ██╔═══██╗██╔══██╗██╔════╝
$2  ██║   ██║██████╔╝███████╗
$2  ██║   ██║██╔═══╝ ╚════██║
$2  ╚██████╔╝██║     ███████║
$2   ╚═════╝ ╚═╝     ╚══════╝
EOF
  local extra=""
  command -v docker  >/dev/null 2>&1 && extra+='    { "type": "command", "key": "  Docker",  "keyColor": "blue",    "text": "docker ps -q 2>/dev/null | wc -l | xargs -I{} echo \"{} running containers\" || echo n/a" },
'
  command -v kubectl >/dev/null 2>&1 && extra+='    { "type": "command", "key": "  K8s ctx", "keyColor": "blue",    "text": "kubectl config current-context 2>/dev/null || echo none" },
'
  cat > "$cfg/config.jsonc" <<EOF
// devops-toolbox fastfetch banner
{
  "\$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
  "logo": {
    "type": "file",
    "source": "$cfg/devops-logo.txt",
    "color": { "1": "cyan", "2": "magenta" },
    "padding": { "top": 1, "left": 1, "right": 3 }
  },
  "display": { "separator": " ➜ ", "key": { "width": 13 } },
  "modules": [
    "break",
    { "type": "title", "format": "{user-name-colored}{at-symbol-colored}{host-name-colored}" },
    { "type": "custom", "format": "\u001b[90m──────────────────────────────────────────" },
    { "type": "os",       "key": "  OS",      "keyColor": "cyan" },
    { "type": "kernel",   "key": "  Kernel",  "keyColor": "cyan" },
    { "type": "host",     "key": "  Host",    "keyColor": "cyan" },
    { "type": "uptime",   "key": "  Uptime",  "keyColor": "cyan" },
    { "type": "command",  "key": "  Load",    "keyColor": "cyan", "text": "cut -d' ' -f1-3 /proc/loadavg" },
    { "type": "custom", "format": "\u001b[90m──────────────────────────────────────────" },
    { "type": "cpu",      "key": "  CPU",     "keyColor": "magenta" },
    { "type": "memory",   "key": "  Memory",  "keyColor": "magenta" },
    { "type": "swap",     "key": "  Swap",    "keyColor": "magenta" },
    { "type": "disk",     "key": "  Disk",    "keyColor": "magenta", "folders": "/" },
    { "type": "localip",  "key": "  IP",      "keyColor": "magenta", "compact": true },
    { "type": "custom", "format": "\u001b[90m──────────────────────────────────────────" },
$extra    { "type": "shell",    "key": "  Shell",   "keyColor": "blue" },
    { "type": "custom", "format": "\u001b[90m  devops-toolbox ➜ z · fzf · btop · k9s · lazygit" },
    "break",
    { "type": "colors", "symbol": "circle" }
  ]
}
EOF
}

write_shell_config() {
  local sel=" $* "
  # remember enabled shell items across runs
  local id; : > "$STATE_FILE.new"
  for id in "${IDS[@]}"; do
    if [[ "$sel" == *" $id "* ]] || { state_has "$id" && [ "${I_KIND[$id]}" = tool ]; }; then echo "$id" >> "$STATE_FILE.new"; fi
  done
  mv "$STATE_FILE.new" "$STATE_FILE"

  # ---------- aliases.sh ----------
  {
    echo "# Generated by devops-toolbox — re-run the installer to change. Edit ~/.devops-toolbox/custom.sh for your own."
    if state_has alias-general; then cat <<'EOF'

# ── General ──
alias ..='cd ..'; alias ...='cd ../..'; alias ....='cd ../../..'; alias -- -='cd -'
alias ll='ls -alFh --color=auto'; alias la='ls -A --color=auto'; alias l='ls -CF --color=auto'
alias grep='grep --color=auto'; alias egrep='grep -E --color=auto'
alias df='df -h'; alias du='du -h'; alias free='free -h'
alias rm='rm -I'; alias cp='cp -i'; alias mv='mv -i'; alias mkdir='mkdir -p'
alias h='history | grep'; alias c='clear'; alias reload='source ~/.bashrc'
alias ports='ss -tulpn'; alias myip='curl -s https://ifconfig.me; echo'
alias path='echo -e ${PATH//:/\\n}'; alias now='date +"%Y-%m-%d %H:%M:%S"'
alias sysi='systemctl'; alias jl='journalctl -xe'; alias jf='journalctl -f -u'
mkcd() { mkdir -p "$1" && cd "$1"; }
extract() {
  case "$1" in
    *.tar.gz|*.tgz) tar xzf "$1" ;; *.tar.bz2|*.tbz) tar xjf "$1" ;; *.tar.xz) tar xJf "$1" ;;
    *.tar) tar xf "$1" ;; *.zip) unzip "$1" ;; *.gz) gunzip "$1" ;; *.bz2) bunzip2 "$1" ;;
    *.7z) 7z x "$1" ;; *) echo "extract: unknown archive '$1'" ;;
  esac
}
if command -v eza >/dev/null; then
  alias ls='eza --group-directories-first'; alias ll='eza -alh --git --group-directories-first'
  alias la='eza -a --group-directories-first'; alias lt='eza --tree --level=2 --group-directories-first'
fi
command -v bat >/dev/null && alias cat='bat --paging=never --style=plain' && alias bcat='bat'
command -v btop >/dev/null && alias top='btop'
command -v rg >/dev/null && alias rgi='rg -i'
EOF
    fi
    if state_has alias-git; then cat <<'EOF'

# ── Git ──
alias g='git'; alias gs='git status -sb'; alias ga='git add'; alias gaa='git add -A'
alias gc='git commit -m'; alias gca='git commit --amend --no-edit'; alias gp='git push'; alias gpl='git pull --rebase'
alias gl='git log --oneline --graph --decorate -20'; alias gla='git log --oneline --graph --decorate --all'
alias gd='git diff'; alias gds='git diff --staged'; alias gco='git checkout'; alias gsw='git switch'
alias gb='git branch'; alias gst='git stash'; alias gstp='git stash pop'; alias gf='git fetch --all --prune'
command -v lazygit >/dev/null && alias lg='lazygit'
EOF
    fi
    if state_has alias-k8s; then cat <<'EOF'

# ── Kubernetes ──
alias k='kubectl'
alias kg='kubectl get'; alias kgp='kubectl get pods'; alias kgpa='kubectl get pods -A'; alias kgpw='kubectl get pods -o wide'
alias kgs='kubectl get svc'; alias kgd='kubectl get deploy'; alias kgn='kubectl get nodes -o wide'; alias kgi='kubectl get ingress'
alias kga='kubectl get all'; alias kge='kubectl get events --sort-by=.lastTimestamp'
alias kd='kubectl describe'; alias kdp='kubectl describe pod'; alias kl='kubectl logs -f'; alias kex='kubectl exec -it'
alias kaf='kubectl apply -f'; alias kdel='kubectl delete'; alias krr='kubectl rollout restart'; alias kpf='kubectl port-forward'
alias ktop='kubectl top pods'
if command -v kubens >/dev/null; then alias kns='kubens'; alias kctx='kubectx'
else
  kns()  { kubectl config set-context --current --namespace="$1"; }
  kctx() { if [ -n "$1" ]; then kubectl config use-context "$1"; else kubectl config get-contexts; fi; }
fi
command -v k9s >/dev/null && alias k9='k9s'
command -v sofka >/dev/null && alias sf='sofka'
EOF
    fi
    if state_has alias-docker; then cat <<'EOF'

# ── Docker ──
alias d='docker'; alias dps='docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"'
alias dpsa='docker ps -a --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"'; alias di='docker images'
alias dex='docker exec -it'; alias dlog='docker logs -f'; alias dstop='docker stop $(docker ps -q)'
alias dprune='docker system prune -af'; alias dvol='docker volume ls'; alias dnet='docker network ls'
alias dc='docker compose'; alias dcu='docker compose up -d'; alias dcd='docker compose down'
alias dcl='docker compose logs -f'; alias dcp='docker compose ps'; alias dcr='docker compose restart'
command -v lazydocker >/dev/null && alias ld='lazydocker'
EOF
    fi
  } > "$TOOLBOX_HOME/aliases.sh"

  # ---------- init.sh ----------
  local banner=1; [ "$OPT_NO_BANNER" = 1 ] && banner=0
  cat > "$TOOLBOX_HOME/init.sh" <<EOF
# devops-toolbox init — sourced from ~/.bashrc  (v$TOOLBOX_VERSION)
case ":\$PATH:" in *":\$HOME/.local/bin:"*) ;; *) export PATH="\$HOME/.local/bin:\$PATH" ;; esac
case ":\$PATH:" in *":\$HOME/.devops-toolbox/bin:"*) ;; *) export PATH="\$HOME/.devops-toolbox/bin:\$PATH" ;; esac
[[ \$- == *i* ]] || return 0   # everything below is for interactive shells only
: "\${DEVOPS_TOOLBOX_BANNER:=$banner}"
: "\${DEVOPS_TOOLBOX_THEME:=${DEVOPS_TOOLBOX_THEME:-ocean}}"   # change with: toolbox-theme <name>
EOF
  cat >> "$TOOLBOX_HOME/init.sh" <<'EOF'
export EDITOR="${EDITOR:-vim}"
HISTSIZE=50000; HISTFILESIZE=100000; HISTCONTROL=ignoreboth:erasedups; shopt -s histappend cdspell 2>/dev/null

# completions
command -v kubectl >/dev/null && source <(kubectl completion bash 2>/dev/null) && complete -o default -F __start_kubectl k
command -v helm    >/dev/null && source <(helm completion bash 2>/dev/null)
command -v gh      >/dev/null && source <(gh completion -s bash 2>/dev/null)
command -v terraform >/dev/null && complete -C "$(command -v terraform)" terraform
command -v tofu    >/dev/null && complete -C "$(command -v tofu)" tofu
command -v aws_completer >/dev/null && complete -C "$(command -v aws_completer)" aws

# tool hooks
command -v zoxide   >/dev/null && eval "$(zoxide init bash)"
command -v fzf      >/dev/null && { eval "$(fzf --bash 2>/dev/null)" || true; }
[ -f "$HOME/.devops-toolbox/fzf.sh" ] && . "$HOME/.devops-toolbox/fzf.sh"
command -v starship >/dev/null && eval "$(starship init bash)"

. "$HOME/.devops-toolbox/aliases.sh"
[ -f "$HOME/.devops-toolbox/custom.sh" ] && . "$HOME/.devops-toolbox/custom.sh"

[ -f "$HOME/.devops-toolbox/banner.sh" ] && . "$HOME/.devops-toolbox/banner.sh"

# SSH logins join the "main" tmux session so the themed top bar is always visible.
#   Opt out: export DEVOPS_TOOLBOX_TMUX=0 in custom.sh. Not exec'd: if tmux fails you still get this shell.
#   Only the first shell of the SSH login (SHLVL 1) attaches, never a nested 'bash' or 'bash -ic ...'.
if [ "${DEVOPS_TOOLBOX_TMUX:-1}" = 1 ] && [ -n "$SSH_CONNECTION" ] && [ -z "$TMUX" ] && [ -t 0 ] &&
   [ "${SHLVL:-1}" -le 1 ] && [ "$TERM_PROGRAM" != vscode ] &&
   [ -f "$HOME/.devops-toolbox/tmux-theme.conf" ] && command -v tmux >/dev/null; then
  tmux new-session -A -s main
  echo "  (left tmux: back in a plain shell. Reattach with: tmux a)"
fi

# login banner, once per session (inside tmux: once per tmux session, not per window)
#   DEVOPS_TOOLBOX_BANNER=1 → toolbox banner · fastfetch → fastfetch · 0 → off   (set it in custom.sh)
if [ -z "$DEVOPS_TOOLBOX_BANNER_SHOWN" ]; then
  export DEVOPS_TOOLBOX_BANNER_SHOWN=1
  [ -n "$TMUX" ] && tmux set-environment DEVOPS_TOOLBOX_BANNER_SHOWN 1 2>/dev/null
  case "$DEVOPS_TOOLBOX_BANNER" in
    1|toolbox) declare -F tb_banner >/dev/null && tb_banner ;;
    fastfetch) command -v fastfetch >/dev/null && fastfetch 2>/dev/null ;;
  esac
fi
EOF

  # ---------- fzf.sh (dotfile) ----------
  if state_has dot-fzf; then cat > "$TOOLBOX_HOME/fzf.sh" <<'EOF'
# devops-toolbox fzf defaults
if command -v fd >/dev/null; then
  export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
  export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
fi
export FZF_DEFAULT_OPTS='--height 45% --layout=reverse --border=rounded --info=inline
  --color=fg:#c0caf5,hl:#7dcfff,fg+:#ffffff,bg+:#283457,hl+:#7dcfff,info:#e0af68,prompt:#bb9af7,pointer:#f7768e,marker:#9ece6a,spinner:#9ece6a,header:#7aa2f7'
command -v bat >/dev/null && export FZF_CTRL_T_OPTS="--preview 'bat --color=always --style=numbers --line-range=:200 {}'"
command -v eza >/dev/null && export FZF_ALT_C_OPTS="--preview 'eza --tree --level=2 --color=always {} | head -100'"
# fe: fuzzy-open file in $EDITOR | fkill: fuzzy kill process | fh: fuzzy history
fe()    { local f; f=$(fzf --query="$1") && ${EDITOR:-vim} "$f"; }
fkill() { local p; p=$(ps -ef | sed 1d | fzf -m --header='select process(es) to kill' | awk '{print $2}'); [ -n "$p" ] && echo "$p" | xargs kill -"${1:-15}"; }
fh()    { eval "$(history | fzf --tac --no-sort | sed -E 's/^ *[0-9]+ *//')"; }
command -v kubectl >/dev/null && kpod() { kubectl get pods -A --no-headers | fzf | awk '{print "-n "$1" "$2}'; }
EOF
  else rm -f "$TOOLBOX_HOME/fzf.sh"; fi
  state_has tmux-bar || rm -f "$TOOLBOX_HOME/tmux-theme.conf" "$TOOLBOX_HOME/tmux-colors"

  touch "$TOOLBOX_HOME/custom.sh"
  [ -f "$HOME/.bashrc" ] || touch "$HOME/.bashrc"
  grep -qF '# devops-toolbox' "$HOME/.bashrc" || printf '\n%s\n' "$BASHRC_LINE" >> "$HOME/.bashrc"
  emit_banner_sh "$TOOLBOX_HOME/banner.sh"
  command -v fastfetch >/dev/null 2>&1 && write_fastfetch_config
  return 0
}

# ──────────────────────────── uninstall ─────────────────────────────
do_uninstall() {
  printf "\n${B}${RED}Uninstall DevOps Toolbox${R}\n\n"
  if [ -f "$BINS_FILE" ]; then
    info "Binaries installed by the toolbox:"; sed 's/^/      /' "$BINS_FILE"
  fi
  if [ "$OPT_YES" = 0 ]; then
    printf "\n  Remove shell config and these binaries? [y/N] "; read -r a </dev/tty; [[ "$a" =~ ^[Yy] ]] || exit 0
  fi
  local s=""; [ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null && s=sudo
  if [ -f "$BINS_FILE" ]; then
    while read -r f; do
      [ -n "$f" ] || continue
      case "$f" in "$HOME"/*) rm -f "$f" ;; *) $s rm -f "$f" ;; esac
    done < "$BINS_FILE"
  fi
  sed -i '/# devops-toolbox$/d' "$HOME/.bashrc" 2>/dev/null
  command -v k3s >/dev/null 2>&1 && warn "k3s stays installed (system service). Remove it with: toolbox-k3s delete k3s (before uninstalling), or sudo /usr/local/bin/k3s-uninstall.sh"
  rm -rf "$TOOLBOX_HOME"
  ok "Removed. Packages from apt/dnf (tmux, htop, docker, …) were left in place."
  ok "Open a new shell to finish."
  exit 0
}

# ──────────────────────────── TUI ───────────────────────────────────
TTY_OK=0
if [ -r /dev/tty ] && [ -w /dev/tty ] && { exec 3</dev/tty; } 2>/dev/null; then TTY_OK=1; fi

read_key() {  # sets KEY to: up down left right space enter a q b or the char
  local k rest
  IFS= read -rsn1 -u 3 k || { KEY=q; return; }
  if [ "$k" = $'\e' ]; then
    IFS= read -rsn2 -t 0.05 -u 3 rest
    case "$rest" in '[A'|'OA') KEY=up ;; '[B'|'OB') KEY=down ;; '[C') KEY=right ;; '[D') KEY=left ;; *) KEY=esc ;; esac
  elif [ -z "$k" ]; then KEY=enter
  elif [ "$k" = " " ]; then KEY=space
  else
    case "$k" in k) KEY=up ;; j) KEY=down ;; *) KEY="$k" ;; esac
  fi
}

banner() {
  printf '\e[H\e[2J'
  tb__init
  local priv="sudo ✔ → $BIN_DIR"
  [ "$HAS_ROOT" = 1 ] || priv="no sudo → $BIN_DIR"
  local rows; rows=$({ stty size </dev/tty; } 2>/dev/null | cut -d" " -f1)
  if [ "${rows:-24}" -ge 34 ]; then
    echo; tb_logo; tb_tag "toolbox installer v$TOOLBOX_VERSION"
  else
    printf '\n  %s%sDEVOPS TOOLBOX%s %sinstaller v%s%s\n' "$TB_P" "$TB_B" "$TB_R" "$TB_D" "$TOOLBOX_VERSION" "$TB_R"
  fi
  tb_rule
  tb_text "System: $OS_PRETTY * $ARCH_X * $PKG * $priv"
  tb_rule
  echo
}

declare -A SEL VER
choose_profile() {
  local cur=0 n=${#PROFILES[@]} i p
  printf '\e[?25l'
  while true; do
    banner
    printf "  ${B}Step 1/3 · Choose a profile${R}  ${DIM}(you can fine-tune every item next)${R}\n\n"
    for i in "${!PROFILES[@]}"; do
      p=${PROFILES[$i]}
      if [ "$i" = "$cur" ]; then printf "  ${CYN}❯ ◉ ${B}%-12s${R} ${CYN}%s${R}\n" "${P_NAME[$p]}" "${P_DESC[$p]}"
      else printf "    ${DIM}○${R} %-12s ${DIM}%s${R}\n" "${P_NAME[$p]}" "${P_DESC[$p]}"; fi
    done
    printf "\n  ${DIM}↑/↓ move · enter select · q quit${R}\n"
    read_key
    case "$KEY" in
      up) cur=$(( (cur - 1 + n) % n )) ;; down) cur=$(( (cur + 1) % n )) ;;
      enter|space|right) OPT_PROFILE=${PROFILES[$cur]}; return ;;
      q|esc) printf '\e[?25h'; echo; exit 0 ;;
    esac
  done
}

# checklist for one category; returns 0=next, 1=back
checklist() {
  local cat=$1 step=$2 total=$3 ids=() id i cur=0 n mark ver line
  for id in "${IDS[@]}"; do [ "${I_CAT[$id]}" = "$cat" ] && ids+=("$id"); done
  n=${#ids[@]}
  printf '\e[?25l'
  while true; do
    banner
    printf "  ${B}Step 2/3 · %s${R}  ${DIM}(%s/%s · profile: %s)${R}\n\n" "${CAT_NAME[$cat]}" "$step" "$total" "${P_NAME[$OPT_PROFILE]}"
    for i in "${!ids[@]}"; do
      id=${ids[$i]}
      if [ "${SEL[$id]}" = 1 ]; then mark="${GRN}[✔]${R}"; else mark="${DIM}[ ]${R}"; fi
      ver=""
      if [ -n "${VER[$id]}" ]; then ver="${GRN}● ${VER[$id]}${R}"; fi
      if [ "$i" = "$cur" ]; then
        printf "  ${CYN}❯${R} %b ${B}${CYN}%-18s${R} %-42s %b\n" "$mark" "${I_LABEL[$id]}" "${I_DESC[$id]}" "$ver"
      else
        printf "    %b %-18s ${DIM}%-42s${R} %b\n" "$mark" "${I_LABEL[$id]}" "${I_DESC[$id]}" "$ver"
      fi
    done
    printf "\n  ${DIM}↑/↓ move · space toggle · a all/none · enter next · b back · q quit${R}\n"
    printf "  ${DIM}${GRN}●${R}${DIM} = already installed (skipped unless --upgrade)${R}\n"
    read_key
    case "$KEY" in
      up)    cur=$(( (cur - 1 + n) % n )) ;;
      down)  cur=$(( (cur + 1) % n )) ;;
      space|x) id=${ids[$cur]}; if [ "${SEL[$id]}" = 1 ]; then SEL[$id]=0; else SEL[$id]=1; fi ;;
      a|A)   local any=0; for id in "${ids[@]}"; do [ "${SEL[$id]}" = 1 ] || any=1; done
             for id in "${ids[@]}"; do SEL[$id]=$any; done ;;
      enter|right) return 0 ;;
      b|left) return 1 ;;
      q|esc) printf '\e[?25h'; echo; exit 0 ;;
    esac
  done
}

confirm_selection() {
  local id c count=0
  banner
  printf "  ${B}Step 3/3 · Review${R}\n\n"
  for c in "${CATEGORIES[@]}"; do
    local line=""
    for id in "${IDS[@]}"; do
      [ "${I_CAT[$id]}" = "$c" ] && [ "${SEL[$id]}" = 1 ] || continue
      count=$((count + 1))
      if [ -n "${VER[$id]}" ] && [ "$OPT_UPGRADE" = 0 ] && [ "${I_KIND[$id]}" = tool ]; then line+="${DIM}${I_LABEL[$id]}(skip)${R}  "
      else line+="${GRN}${I_LABEL[$id]}${R}  "; fi
    done
    [ -n "$line" ] && printf "  ${B}%-24s${R} %b\n" "${CAT_NAME[$c]}" "$line"
  done
  [ "$count" -gt 0 ] || { printf "\n  ${YLW}Nothing selected.${R}\n"; return 1; }
  printf "\n  ${B}%s${R} items selected. Install now? ${DIM}[Y/n/b=back]${R} " "$count"
  printf '\e[?25h'
  local a; IFS= read -rsn1 -u 3 a; echo
  case "$a" in n|N|q) exit 0 ;; b|B) return 1 ;; *) return 0 ;; esac
}

run_menus() {
  [ -n "$OPT_PROFILE" ] || choose_profile
  apply_profile
  local i=0 n=${#CATEGORIES[@]}
  while true; do
    while [ "$i" -lt "$n" ]; do
      if checklist "${CATEGORIES[$i]}" $((i + 1)) "$n"; then i=$((i + 1))
      elif [ "$i" -gt 0 ]; then i=$((i - 1))
      else choose_profile; apply_profile; fi
    done
    confirm_selection && return
    i=$((n - 1))
  done
}

apply_profile() {
  local id
  [ -n "${P_ITEMS[$OPT_PROFILE]+x}" ] || die "Unknown profile '$OPT_PROFILE' (use: ${PROFILES[*]})"
  for id in "${IDS[@]}"; do SEL[$id]=0; done
  for id in ${P_ITEMS[$OPT_PROFILE]}; do SEL[$id]=1; done
  for id in ${OPT_TOOLS//,/ }; do
    [ -n "${I_CAT[$id]+x}" ] || die "Unknown item '$id' (see --list)"
    SEL[$id]=1
  done
  # keep previously enabled aliases/dotfiles ticked
  for id in "${IDS[@]}"; do [ "${I_KIND[$id]}" != tool ] && state_has "$id" && SEL[$id]=1; done
  [ "$OPT_NO_BANNER" = 1 ] || true
}

# ──────────────────────────── install loop ──────────────────────────
SPIN=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)
RESULT_OK=(); RESULT_SKIP=(); RESULT_FAIL=()
run_item() {
  local id=$1 label=${I_LABEL[$1]} log="$LOG_DIR/$1.log" start=$SECONDS pid i=0 rc v
  if [ "${I_KIND[$id]}" = tool ] && [ -n "${VER[$id]}" ] && [ "$OPT_UPGRADE" = 0 ]; then
    printf "  ${DIM}○ %-18s already installed (%s) — skipped${R}\n" "$label" "${VER[$id]}"
    RESULT_SKIP+=("$id"); return
  fi
  ( "install_$id" ) >"$log" 2>&1 &
  pid=$!
  if [ -t 1 ]; then
    printf '\e[?25l'
    while kill -0 "$pid" 2>/dev/null; do
      printf "\r  ${CYN}%s${R} %-18s ${DIM}installing… %ss${R}${EL}" "${SPIN[i++ % 10]}" "$label" $((SECONDS - start))
      sleep 0.1
    done
    printf '\e[?25h'
  fi
  wait "$pid"; rc=$?
  hash -r
  if [ "$rc" = 0 ]; then
    v=$(tool_version "$id"); [ "${I_KIND[$id]}" = tool ] || v="configured"
    printf "\r  ${GRN}✔${R} %-18s ${GRN}%s${R} ${DIM}(%ss)${R}${EL}\n" "$label" "${v:-done}" $((SECONDS - start))
    RESULT_OK+=("$id")
  else
    printf "\r  ${RED}✖${R} %-18s ${RED}failed${R} ${DIM}— %s${R}${EL}\n" "$label" "$(tail -1 "$log" | cut -c1-60)"
    RESULT_FAIL+=("$id")
  fi
}

ensure_prereqs() {
  local need=() c
  for c in curl tar gzip unzip bzip2 git; do command -v "$c" >/dev/null || need+=("$c"); done
  command -v curl >/dev/null || [ "$HAS_ROOT" = 1 ] || die "curl is required"
  [ ${#need[@]} -eq 0 ] && return
  if [ "$HAS_ROOT" = 1 ]; then
    info "Installing prerequisites: ${need[*]}"
    pkg_install "${need[@]}" ca-certificates >"$LOG_DIR/prereqs.log" 2>&1 || warn "Some prerequisites failed (see $LOG_DIR/prereqs.log)"
  else
    warn "Missing ${need[*]} and no sudo — some installs may fail."
  fi
}

# ──────────────────────────── main ──────────────────────────────────
main() {
  detect_os
  [ "$OPT_UNINSTALL" = 1 ] && do_uninstall
  detect_privileges
  export DEVOPS_TOOLBOX_THEME="${OPT_THEME:-${DEVOPS_TOOLBOX_THEME:-ocean}}"
  case " ocean amber ice snow matrix sand lavender " in *" $DEVOPS_TOOLBOX_THEME "*) ;; *) die "Unknown theme: $DEVOPS_TOOLBOX_THEME" ;; esac
  emit_banner_sh "$TMP/banner.sh"
  # shellcheck disable=SC1091
  . "$TMP/banner.sh"

  local id
  for id in "${IDS[@]}"; do
    if [ "${I_KIND[$id]}" = tool ]; then VER[$id]=$(tool_version "$id")
    elif state_has "$id"; then VER[$id]="enabled"; fi
  done

  if [ "$OPT_YES" = 1 ]; then
    [ -n "$OPT_PROFILE" ] || [ -n "$OPT_TOOLS" ] || die "--yes needs --profile or --tools"
    [ -n "$OPT_PROFILE" ] || OPT_PROFILE=custom
    [ -n "$OPT_TOOLS" ] && [ "$OPT_PROFILE" = custom ] && P_ITEMS[custom]=""
    apply_profile
  else
    [ "$TTY_OK" = 1 ] || die "No terminal available for the menu. Use --profile/--tools with --yes."
    run_menus
    # k3s server: one follow-up question, asked now so the install loop can run unattended
    if [ "${SEL[k3s]}" = 1 ] && [ -z "${VER[k3s]}" ] && [ -z "$OPT_NO_TRAEFIK" ]; then
      local a
      printf "\n  ${CYN}?${R} k3s server: disable the built-in Traefik ingress? (yes if you'll use nginx-ingress etc.) ${DIM}[y/N]${R} "
      IFS= read -rsn1 -u 3 a; echo
      [[ "$a" =~ ^[Yy] ]] && OPT_NO_TRAEFIK=1
    fi
  fi

  local selected=()
  for id in "${IDS[@]}"; do [ "${SEL[$id]}" = 1 ] && selected+=("$id"); done
  [ ${#selected[@]} -gt 0 ] || die "Nothing selected."

  [ -t 1 ] && printf '\e[H\e[2J'
  printf "\n  ${B}${CYN}Installing %s items${R} ${DIM}(logs: %s)${R}\n\n" "${#selected[@]}" "$LOG_DIR"
  ensure_prereqs
  emit_k3s_helper "$TOOLBOX_HOME/bin/toolbox-k3s"   # used by the k3s item and available as a command
  local c printed
  for c in "${CATEGORIES[@]}"; do
    printed=0
    for id in "${selected[@]}"; do
      [ "${I_CAT[$id]}" = "$c" ] || continue
      [ "$printed" = 0 ] && { printf "\n  ${B}${MAG}%s${R}\n" "${CAT_NAME[$c]}"; printed=1; }
      run_item "$id"
    done
  done

  # record successfully installed/configured items (keep skipped ones too)
  write_shell_config "${RESULT_OK[@]}" "${RESULT_SKIP[@]}"

  printf "\n  ${B}────────────────────────── Summary ──────────────────────────${R}\n"
  printf "  ${GRN}✔ %s installed${R}   ${DIM}○ %s skipped${R}   ${RED}✖ %s failed${R}\n" "${#RESULT_OK[@]}" "${#RESULT_SKIP[@]}" "${#RESULT_FAIL[@]}"
  if [ ${#RESULT_FAIL[@]} -gt 0 ]; then
    for id in "${RESULT_FAIL[@]}"; do printf "    ${RED}✖${R} %-14s ${DIM}%s${R}\n" "$id" "$LOG_DIR/$id.log"; done
  fi
  printf "\n"

  # show the new login banner with the freshly written aliases loaded
  if [ "$OPT_NO_BANNER" = 0 ]; then
    ( . "$TOOLBOX_HOME/aliases.sh" 2>/dev/null; . "$TOOLBOX_HOME/banner.sh"; tb_banner )
  fi

  printf "\n  ${B}${GRN}All set!${R} Activate now with:  ${B}${CYN}exec bash${R}\n"
  printf "  ${DIM}Your own aliases → ~/.devops-toolbox/custom.sh · Banner: DEVOPS_TOOLBOX_BANNER=1|fastfetch|0 · Commands → toolbox-help${R}\n"
  printf "  ${DIM}Re-run any time to add tools · --upgrade to update · --uninstall to remove${R}\n\n"
  printf "  ${YLW}Tip:${R} fonts render on the computer you SSH ${B}from${R}, not on this server. For the best banner + icons,\n"
  printf "  run ONE of these on ${B}your own PC/laptop${R} (not here):\n"
  printf "    ${DIM}Windows:${R}       irm https://raw.githubusercontent.com/$TOOLBOX_REPO/main/install-fonts.ps1 | iex\n"
  printf "    ${DIM}macOS/Linux:${R}   curl -fsSL https://raw.githubusercontent.com/$TOOLBOX_REPO/main/install-fonts.sh | bash\n\n"
  [ "$PKG" ] && [[ " ${RESULT_OK[*]} " == *" docker "* ]] && [ "$(id -u)" -ne 0 ] && warn "Log out and back in to use docker without sudo."
  return 0
}

main
