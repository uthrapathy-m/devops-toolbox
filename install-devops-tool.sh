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
OPT_PROFILE=""; OPT_TOOLS=""; OPT_YES=0; OPT_UPGRADE=0; OPT_UNINSTALL=0; OPT_LIST=0; OPT_NO_BANNER=0

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
      --no-banner      Do not enable the fastfetch login banner
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

PROFILES=(minimal core k8s cloud everything custom)
declare -A P_NAME=(
  [minimal]="Minimal" [core]="Core CLI" [k8s]="K8s Ops" [cloud]="Cloud"
  [everything]="Everything" [custom]="Custom"
)
declare -A P_DESC=(
  [minimal]="fzf, zoxide, bat, btop + general/git aliases"
  [core]="All modern CLI utilities, tmux, starship, dotfiles"
  [k8s]="Core CLI + docker, kubectl, helm, k9s, stern, aliases"
  [cloud]="Core CLI + terraform, opentofu, ansible, aws/az/gcloud"
  [everything]="Every item in the catalog"
  [custom]="Start from nothing, pick item by item"
)
_P_MIN="fzf zoxide bat btop fastfetch alias-general alias-git"
_P_CORE="$_P_MIN eza ripgrep fd jq yq tldr ncdu tmux delta lazygit starship htop dot-tmux dot-fzf"
declare -A P_ITEMS=(
  [minimal]="$_P_MIN"
  [core]="$_P_CORE"
  [k8s]="$_P_CORE docker kubectl helm k9s kubectx stern lazydocker dive alias-k8s alias-docker"
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
# status bar
set -g status-position bottom
set -g status-style "bg=colour235,fg=colour250"
set -g status-left "#[bg=colour39,fg=colour235,bold] #S #[default] "
set -g status-right "#[fg=colour39]#H #[fg=colour245]| %Y-%m-%d %H:%M "
set -g status-left-length 30
setw -g window-status-current-format "#[bg=colour39,fg=colour235,bold] #I:#W "
setw -g window-status-format " #I:#W "
set -g pane-active-border-style "fg=colour39"
EOF
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
[[ \$- == *i* ]] || return 0   # everything below is for interactive shells only
: "\${DEVOPS_TOOLBOX_BANNER:=$banner}"
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

# login banner (once per session, not inside tmux) — disable: export DEVOPS_TOOLBOX_BANNER=0
if [ "$DEVOPS_TOOLBOX_BANNER" = 1 ] && [ -z "$TMUX" ] && [ -z "$DEVOPS_TOOLBOX_BANNER_SHOWN" ] && command -v fastfetch >/dev/null; then
  export DEVOPS_TOOLBOX_BANNER_SHOWN=1
  fastfetch 2>/dev/null
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

  touch "$TOOLBOX_HOME/custom.sh"
  [ -f "$HOME/.bashrc" ] || touch "$HOME/.bashrc"
  grep -qF '# devops-toolbox' "$HOME/.bashrc" || printf '\n%s\n' "$BASHRC_LINE" >> "$HOME/.bashrc"
  command -v fastfetch >/dev/null 2>&1 && write_fastfetch_config
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
  printf "${CYN}${B}"
  cat <<'EOF'
   ╔═══════════════════════════════════════════════════════════╗
   ║   ___                ___                _____         _   ║
   ║  |   \ _____ _____  / _ \ _ __ ___     |_   _|__  ___| |  ║
   ║  | |) / -_) V / _ \| (_) | '_ (_-<       | |/ _ \/ _ \ |  ║
   ║  |___/\___|\_/\___/ \___/| .__/__/       |_|\___/\___/_|  ║
   ║                          |_|          toolbox installer   ║
   ╚═══════════════════════════════════════════════════════════╝
EOF
  printf "${R}"
  local priv="${GRN}sudo ✔${R} → $BIN_DIR"
  [ "$HAS_ROOT" = 1 ] || priv="${YLW}no sudo${R} → $BIN_DIR"
  printf "   ${DIM}%s · %s · %s${R} · %b\n\n" "$OS_PRETTY" "$ARCH_X" "$PKG" "$priv"
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
  fi

  local selected=()
  for id in "${IDS[@]}"; do [ "${SEL[$id]}" = 1 ] && selected+=("$id"); done
  [ ${#selected[@]} -gt 0 ] || die "Nothing selected."

  [ -t 1 ] && printf '\e[H\e[2J'
  printf "\n  ${B}${CYN}Installing %s items${R} ${DIM}(logs: %s)${R}\n\n" "${#selected[@]}" "$LOG_DIR"
  ensure_prereqs
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

  if command -v fastfetch >/dev/null 2>&1; then
    fastfetch 2>/dev/null
  fi

  printf "\n  ${B}${GRN}All set!${R} Activate now with:  ${B}${CYN}exec bash${R}\n"
  printf "  ${DIM}Your own aliases → ~/.devops-toolbox/custom.sh · Disable banner → export DEVOPS_TOOLBOX_BANNER=0${R}\n"
  printf "  ${DIM}Re-run any time to add tools · --upgrade to update · --uninstall to remove${R}\n\n"
  [ "$PKG" ] && [[ " ${RESULT_OK[*]} " == *" docker "* ]] && [ "$(id -u)" -ne 0 ] && warn "Log out and back in to use docker without sudo."
  return 0
}

main
