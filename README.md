# DevOps Toolbox

Make a fresh Linux server ready for DevOps work with one command. An interactive, colourful menu lets you choose what goes on the box: modern CLI tools, Kubernetes and cloud CLIs, alias packs and dotfiles. Then it shows a custom login banner.

```bash
curl -fsSL https://raw.githubusercontent.com/uthrapathy-m/devops-toolbox/main/install-devops-tool.sh | bash
```

**Full guide with examples:** [docs/devops-toolbox-guide.pdf](docs/devops-toolbox-guide.pdf) (also as [HTML](docs/devops-toolbox-guide.html), download and open in a browser).

<p align="center"><img src="assets/banner-ocean.png" alt="DevOps Toolbox login banner (Ocean theme)" width="820"></p>

The installer menu looks like this:

```
  Step 2/3 · CLI Utilities  (1/5 · profile: Core CLI)

  ❯ [✔] fzf                Fuzzy finder (Ctrl-R history, Ctrl-T files)  ● 0.75.0
    [✔] zoxide (z)         Smarter cd that learns your dirs
    [ ] bat                cat with syntax highlighting
    ...
  ↑/↓ move · space toggle · a all/none · enter next · b back · q quit
```

## Getting started

There are two steps: fonts once on the computer you type on, then the toolbox on each server.

### Step 1: Fonts on your own computer (once)

Run this on the machine your terminal app runs on, **not** on the server.

- **Windows** (PowerShell):
  ```powershell
  irm https://raw.githubusercontent.com/uthrapathy-m/devops-toolbox/main/install-fonts.ps1 | iex
  ```
- **Linux or macOS laptop/desktop:**
  ```bash
  curl -fsSL https://raw.githubusercontent.com/uthrapathy-m/devops-toolbox/main/install-fonts.sh | bash
  ```

Then pick **JetBrainsMono Nerd Font Mono** in your terminal's font settings and restart the terminal. See [Fonts](#fonts-install-on-your-own-computer) for details.

### Step 2: The toolbox on each server

```bash
# 1. Connect to the server
ssh user@your-server

# 2. Run the installer and follow the menus
curl -fsSL https://raw.githubusercontent.com/uthrapathy-m/devops-toolbox/main/install-devops-tool.sh | bash

# 3. Load the new setup in your current session
exec bash
```

In the installer:

1. If you're not root, it asks whether to use sudo. Say **Y** if you have sudo access.
2. **Choose a profile** with ↑/↓ and press Enter.
3. **Go through the 5 category checklists.** Space ticks or unticks a tool, `a` selects all, Enter goes to the next category, `b` goes back.
4. **Review** the list and press **Y** to install.
5. You'll see the install progress, a summary and then the banner.

### Step 3: Use it

```bash
toolbox-help           # see every alias and tool installed on this server
toolbox-theme          # preview the 7 colour themes
toolbox-theme matrix   # switch theme (saved)
```

Each new SSH login shows the banner automatically.

### Optional: Skip the menus

Useful when you already know what you want, or in automation like cloud-init:

```bash
# K8s Ops profile, no questions, matrix theme
curl -fsSL https://raw.githubusercontent.com/uthrapathy-m/devops-toolbox/main/install-devops-tool.sh | bash -s -- -p k8s -y --theme matrix

# Just specific tools
curl -fsSL https://raw.githubusercontent.com/uthrapathy-m/devops-toolbox/main/install-devops-tool.sh | bash -s -- -t fzf,btop,zoxide,alias-k8s -y
```

### Later: updating a server you already set up

Re-run the installer. Tools you already have are skipped, and your alias packs and dotfiles stay ticked. Tick any new items you want, or name them directly:

```bash
curl -fsSL https://raw.githubusercontent.com/uthrapathy-m/devops-toolbox/main/install-devops-tool.sh | bash
# or, without menus, just the new items:
curl -fsSL https://raw.githubusercontent.com/uthrapathy-m/devops-toolbox/main/install-devops-tool.sh | bash -s -- -t tmux-bar,sofka,k3d,dot-k8s-tui -y
exec bash
```

- **Add more tools:** run the same `curl ... | bash` again. Anything already installed is skipped.
- **Update everything:** add `-s -- --upgrade` to the end of that command.
- **Remove it:** add `-s -- --uninstall` to the end instead.
- **Something failed?** Each tool's log is at `~/.devops-toolbox/logs/<tool>.log`.

## Login banner

Every new SSH session opens with the banner shown above: the gradient DEVOPS logo plus live system data (kernel, uptime, OS, load, memory, disk, IP and, when installed, Docker and Kubernetes status).

### Themes

There are 7 colour themes, inspired by [bashfolio](https://github.com/rushhiii/bashfolio). **Ocean** is the default.

<p align="center"><img src="assets/themes.png" alt="All 7 banner themes" width="900"></p>

| Theme | Logo gradient | Accent |
|---|---|---|
| `ocean` | cyan → deep blue | orange |
| `amber` | gold → bronze | white |
| `ice` | ice-blue → steel | pink |
| `snow` | white → grey | orange / yellow |
| `matrix` | neon green → dark green | white |
| `sand` | beige → tan | orange-red |
| `lavender` | purple → blue | green text, purple accent |

```bash
toolbox-theme              # preview colour swatches for every theme
toolbox-theme matrix       # switch (saved to ~/.devops-toolbox/custom.sh)
bash install-devops-tool.sh --theme amber   # choose at install time
```

Tip: give each environment its own colour (for example, `matrix` on prod and `ocean` on dev) so you can tell at a glance which server you're on.

- `toolbox-help` lists the aliases and tools that are actually installed on this machine.
- `toolbox-banner` shows the banner again.
- `DEVOPS_TOOLBOX_BANNER` controls what appears at login: `1` for this banner (default), `fastfetch` for the detailed fastfetch view, or `0` for nothing. Set it in `~/.devops-toolbox/custom.sh`.

## Pinned banner (tmux)

The **pinned banner** item keeps a compact DEVOPS banner fixed at the top of the screen. Your shell and everything you run scroll underneath it:

<p align="center"><img src="assets/pinned-banner.png" alt="Pinned DEVOPS banner above the shell inside tmux" width="860"></p>

- **What it shows:** the gradient logo, the date and time, `© year user@host`, then 2 live lines: kernel, uptime, load, CPUs and OS; memory, disk, IP and the Kubernetes context. It refreshes every 5 seconds, and `toolbox-theme <name>` recolours it live, together with k9s and sofka.
- **How it works:** it's a read-only tmux pane in every window, so typing never goes into it and `clear` or long output never moves it. There's no tmux status bar.
- **Auto-attach:** every SSH login joins a tmux session called `main`. If your connection drops, your work keeps running; SSH back in and you're where you left off.
- **No repeated logo:** the shell below only prints the welcome lines. If the pinned banner is off or the screen is too small, the full banner shows once instead.
- **Small screens:** it's skipped automatically when the window is smaller than 26 rows or 60 columns.
- **Safe by design:** only the first shell of an SSH login attaches; nested shells, `bash -c` and VS Code terminals never do. If tmux ever fails to start, you still get a normal shell.
- **Turning things off:** `toolbox-pin off` / `toolbox-pin on` turns the pinned banner off or on everywhere, and the choice is remembered. To stop auto-attaching to tmux, add `export DEVOPS_TOOLBOX_TMUX=0` to `~/.devops-toolbox/custom.sh`.

Keys (prefix `Ctrl-a`):

| Keys | Action |
|---|---|
| `Ctrl-a` `b` | Hide / show the pinned banner in this window |
| `Ctrl-a` `z` | Zoom the current pane to full screen (again to restore) |
| `Ctrl-a` `w` | List windows and switch (there's no tab bar) |
| `Ctrl-a` `S` | Show / hide the tmux status bar, if you want it |
| `Ctrl-a` `d` | Detach (work keeps running); reattach with `tmux a` or a new SSH login |
| `Ctrl-a` `c` / `n` / `p` | New window / next / previous |
| `Ctrl-a` <code>&#124;</code> / `-` | Split side by side / top and bottom |
| `Ctrl-a` `h` `j` `k` `l` | Move between panes (`H` `J` `K` `L` to resize) |
| `Ctrl-a` `[` | Scroll / copy mode (`q` to leave) |

## k9s and sofka

Pick **k9s / sofka setup** (it's in the K8s Ops profile) to get both Kubernetes terminal UIs ready to use:

- **Themed skins.** k9s gets a skin generated from your banner theme. sofka gets the closest built-in skin: Ocean → tokyo-night, Amber → gruvbox-dark, Ice → nord, Snow → one-dark, Matrix → monokai recoloured green, Sand → flexoki-dark, Lavender → dracula. `toolbox-theme <name>` switches the banner, k9s and sofka together.
- **k9s plugins:**

  | Key | Where | What it does |
  |---|---|---|
  | `Ctrl-L` | pods, deployments, statefulsets, daemonsets | stern logs across all pods and containers |
  | `Shift-D` | containers | Attach a netshoot debug container |
  | `Shift-I` | containers | Inspect the image's layers with dive |
  | `Shift-E` | pods, deployments | Watch namespace events |
  | `Ctrl-G` | namespaces | `kubectl get all` for the namespace |

- **k9s hotkeys:** `Shift-0` … `Shift-7` jump to pods, deployments, services, ingresses, nodes, events, Helm releases and namespaces.
- **Aliases** in both tools: `:dp`, `:sec`, `:cm`, `:jo`, `:cj` (k9s also gets `:crb`, `:rb`, `:np` and `:pvc`).
- **From the shell:** `k9` starts k9s and `sf` starts sofka. `toolbox-help` includes a cheat sheet for keys inside k9s.

sofka can also convert your k9s setup with `sofka import k9s`.

## k3s and k3d clusters

Two ways to get a Kubernetes cluster. Both use the upstream `k3d` and `k3s` commands directly; the toolbox adds no wrapper.

| | **k3d** (in K8s Ops) | **k3s server** (opt-in) |
|---|---|---|
| What | k3s running inside Docker containers | A real k3s install on the machine (systemd) |
| Best for | Quick test clusters, multi-node on one box | A cluster that survives reboots, with real workers joining |
| Needs | Docker | sudo/root |

### k3d

```bash
k3d cluster create dev --agents 2      # 1 server + 2 workers in Docker
k3d cluster list
k3d cluster delete dev
```

k3d adds each cluster to `~/.kube/config` as the context `k3d-<name>`.

### k3s server

Ticking **k3s server** in the menu runs the official installer (`curl -sfL https://get.k3s.io | sh -`). The installer asks once whether to disable Traefik; use `--no-traefik` when running non-interactively. To do it by hand:

```bash
curl -sfL https://get.k3s.io | sh -s - --disable traefik   # drop the flag to keep Traefik
mkdir -p ~/.kube && sudo cat /etc/rancher/k3s/k3s.yaml > ~/.kube/config && chmod 600 ~/.kube/config
kubectl get nodes
sudo /usr/local/bin/k3s-uninstall.sh                       # remove k3s
```

The toolbox's k3s item writes the kubeconfig to `~/.kube/config` only if you don't have one yet. Otherwise it writes `~/.kube/k3s.yaml` and leaves your config alone (`export KUBECONFIG=~/.kube/config:~/.kube/k3s.yaml` to use both).

### Adding worker machines (k3s)

1. On the **server**, get the token and private IP:
   ```bash
   sudo cat /var/lib/rancher/k3s/server/node-token
   hostname -I | awk '{print $1}'
   ```
2. On each **worker**, run:
   ```bash
   curl -sfL https://get.k3s.io | K3S_URL=https://<server-private-ip>:6443 K3S_TOKEN=<token> sh -
   ```
3. **On AWS**, the security group must allow **TCP 6443** (API server), **UDP 8472** (flannel) and **TCP 10250** (kubelet) between the nodes. Allow them from the same security group or the VPC CIDR.
4. Check with `kubectl get nodes` on the server. Remove a worker with `sudo /usr/local/bin/k3s-agent-uninstall.sh`.

The join token works like a cluster password. Don't paste it into tickets or chat.

## Windows (PowerShell + Windows Terminal)

The same banner, themes and alias packs for your own Windows PC, in PowerShell 5.1 and 7:

```powershell
irm https://raw.githubusercontent.com/uthrapathy-m/devops-toolbox/main/install-toolbox.ps1 | iex
```

- **Menus:** pick a profile (minimal, core, k8s, cloud, everything, custom), tick single items, pick a theme. Tools are installed with **winget**; anything already installed is skipped.
- **Banner + pinned pane:** every new PowerShell tab in Windows Terminal gets a 10-row pane at the top with the compact banner (date/time and live stats, redrawn every 5 s). It closes with its tab and hides while `ssh` runs. `toolbox-pin` toggles it; `toolbox-pin off` / `on` is remembered.
- **Themes:** the same 7 themes, plus matching Windows Terminal colour schemes ("DevOps Toolbox Ocean", ...). `toolbox-theme amber` changes both. `settings.json` is backed up first.
- **Aliases:** the Linux packs, except that git commit/push/log are `gcmsg`, `gpush`, `glog` (`gc`, `gp`, `gl` are built-in PowerShell aliases), and `ls`/`cat` are left alone (`ll`, `la`, `lt`, `bcat` instead). Run `toolbox-help` for the list.
- **Files:** `~\.devops-toolbox	oolbox.ps1` (regenerated), `custom.ps1` (yours, never overwritten), one line in your PowerShell profile.

```powershell
.\install-toolbox.ps1 -Profile k8s -Theme ice -Yes   # no menus
.\install-toolbox.ps1 -List                          # catalog
.\install-toolbox.ps1 -DryRun                        # show what would happen
.\install-toolbox.ps1 -Uninstall                     # remove (winget tools stay)
```

## Fonts (install on your own computer)

Your **SSH client** renders the text, so fonts belong on the computer you SSH *from*, not on the server. The banner works with any monospace font. A Nerd Font makes the block letters crisper and adds the icons used by eza, starship and lazygit.

Both scripts install **CaskaydiaMono Nerd Font** (Cascadia Mono) and **JetBrainsMono Nerd Font** for your user only; no admin rights are needed.

**Windows** (PowerShell). The script can also set the Windows Terminal default font for you, and it backs up `settings.json` first:
```powershell
irm https://raw.githubusercontent.com/uthrapathy-m/devops-toolbox/main/install-fonts.ps1 | iex
```

**macOS / Linux desktop:**
```bash
curl -fsSL https://raw.githubusercontent.com/uthrapathy-m/devops-toolbox/main/install-fonts.sh | bash
```

Then choose **`JetBrainsMono Nerd Font Mono`** or **`CaskaydiaMono Nerd Font Mono`** in your terminal's font settings (Windows Terminal, PuTTY, iTerm2, GNOME Terminal, VS Code and others). Restart the terminal afterwards.

| Option | Effect |
|---|---|
| `-SetDefault jetbrains\|cascadia\|none` (Windows, file mode) | Set or skip the Windows Terminal font without being asked |
| `$env:TOOLBOX_FONT = 'jetbrains'` (Windows, before the one-liner) | Same as above when using `irm \| iex` |
| `--dry-run` / `-DryRun` | Download and list the fonts without installing anything |

## How it works

1. **Pick a profile**: Minimal, Core CLI, K8s Ops, Cloud, Everything or Custom.
2. **Fine-tune each category.** Every item is a checkbox, pre-ticked from the profile you picked.
3. **Review and install.** You get a live spinner for each tool and a summary at the end, followed by your new login banner.

Anything already installed shows `● version` and is skipped. Pass `--upgrade` to reinstall it at the latest version.

## Catalog

| Category | Items |
|---|---|
| CLI Utilities | fzf, zoxide (`z`), bat, eza, ripgrep, fd, jq, yq, tldr, ncdu, tmux, git-delta, lazygit, starship |
| Monitoring | btop, htop, fastfetch (with a custom login banner) |
| Containers & Kubernetes | docker + compose, kubectl, helm, k9s, [sofka](https://github.com/nklmilojevic/sofka), k3d, k3s server, kubectx/kubens, stern, lazydocker, dive |
| Cloud & IaC | terraform, opentofu, ansible, AWS CLI v2, Azure CLI, gcloud |
| Aliases & Dotfiles | General, Git, Kubernetes and Docker alias packs, tmux.conf, fzf defaults, k9s / sofka setup, pinned banner |

Run `--list` to print every item id.

## Non-interactive use (automation, cloud-init)

```bash
# a whole profile, no questions
curl -fsSL https://raw.githubusercontent.com/uthrapathy-m/devops-toolbox/main/install-devops-tool.sh | bash -s -- -p k8s -y

# exact items
curl -fsSL .../install-devops-tool.sh | bash -s -- -t fzf,btop,zoxide,alias-git -y

# upgrade everything already installed
curl -fsSL .../install-devops-tool.sh | bash -s -- -p everything -y --upgrade
```

| Flag | Meaning |
|---|---|
| `-p, --profile` | `minimal`, `core`, `k8s`, `cloud`, `everything`, `custom` |
| `-t, --tools` | Comma-separated item ids (adds to the profile) |
| `-y, --yes` | Skip all menus |
| `-u, --upgrade` | Reinstall tools that are already present |
| `--no-banner` | Don't show the login banner |
| `--theme` | Banner colours: `ocean`, `amber`, `ice`, `snow`, `matrix`, `sand`, `lavender` |
| `--no-traefik` | With the `k3s` item: install k3s without the Traefik ingress |
| `--list` | List item ids and profiles |
| `--uninstall` | Remove the toolbox shell config and the binaries it installed |

## Supported systems

- **Distros:** Ubuntu and Debian (apt); RHEL, Rocky, Alma, CentOS Stream, Fedora and Amazon Linux (dnf/yum).
- **CPU:** x86_64 and arm64 (Graviton, Ampere, Raspberry Pi).
- **Shell:** bash.
- **With sudo or root:** tools go to `/usr/local/bin`, and the system package manager handles tmux, htop, ncdu and docker.
- **Without sudo:** static binaries go to `~/.local/bin`. Tools that only come from the package manager are reported and skipped.

Most tools come from their **latest GitHub release**. If you hit the GitHub API rate limit, run `export GITHUB_TOKEN=...` first.

## What it changes on your machine

| Path | Purpose |
|---|---|
| `~/.bashrc` | One line that sources `~/.devops-toolbox/init.sh` |
| `~/.devops-toolbox/init.sh` | PATH, completions, zoxide, fzf and starship hooks |
| `~/.devops-toolbox/banner.sh` | The login banner and `toolbox-help` |
| `~/.devops-toolbox/aliases.sh` | The alias packs you picked (regenerated on every run) |
| `~/.devops-toolbox/custom.sh` | **Your own** aliases; never overwritten |
| `~/.devops-toolbox/logs/` | One install log per tool |
| `~/.config/fastfetch/` | Banner config and DEVOPS logo |
| `~/.tmux.conf` | Only if you pick it; any existing file is backed up first |
| `~/.config/k9s/` | k9s / sofka setup: skin, `plugins.yaml`, `hotkeys.yaml`, `aliases.yaml` (your own files are backed up first) |
| `~/.config/sofka/config.toml` | k9s / sofka setup: aliases, plus a marked skin block; the rest of the file is yours |

Re-running the script is safe: it never adds duplicate lines and keeps the alias packs you enabled before.

## Handy things you get

- `z <dir>` jumps to directories you visit often. `Ctrl-R` searches history with fzf. `Ctrl-T` finds files with a bat preview.
- `k`, `kgp`, `kl`, `kex`, `kns`, `kctx` for Kubernetes (`k` gets tab completion too).
- `dps`, `dcu`, `dcl`, `dex` for Docker; `gs`, `gl`, `gco`, `lg` for Git.
- `fe` opens a file in your editor, `fkill` kills a process and `fh` re-runs a history entry, all through fzf.
- tmux: prefix `Ctrl-a`, split panes with `|` and `-`, mouse enabled.
- Type `toolbox-help` at any time to see all of these.

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/uthrapathy-m/devops-toolbox/main/install-devops-tool.sh | bash -s -- --uninstall
```
