# DevOps Toolbox

A one-line `curl | bash` installer that turns a freshly SSH'd Linux server into a productive DevOps workstation by installing the tools, aliases and dotfiles the operator picks.

## Language

**Catalog**:
The full set of Items the installer knows how to provide.
_Avoid_: Tool list, registry

**Item**:
One selectable entry in the Catalog, either a Tool, an Alias Pack or a Dotfile.
_Avoid_: Package, option

**Tool**:
An Item that puts an executable on the server (e.g. fzf, btop, kubectl).
_Avoid_: Utility, binary, app

**Alias Pack**:
An Item that adds a themed group of shell aliases (General, Git, Kubernetes, Docker).
_Avoid_: Alias set, shortcuts

**Dotfile**:
An Item that writes an opinionated config for a Tool (e.g. tmux.conf, fzf defaults).
_Avoid_: Config, rc file

**Category**:
A grouping of Items shown together in the menu (CLI Utilities, Monitoring, Containers & Kubernetes, Cloud & IaC, Aliases).
_Avoid_: Section, group

**Profile**:
A named preset that pre-selects a subset of the Catalog (Minimal, Core CLI, K8s Ops, Cloud, Everything, Custom).
_Avoid_: Preset, bundle, role

**Selection**:
The final set of Items the operator confirmed for installation in one run.
_Avoid_: Choices, picks

**Toolbox Home**:
The per-user directory (`~/.devops-toolbox/`) that holds everything the installer writes to the shell environment, sourced from `~/.bashrc` by a single line.
_Avoid_: Config dir, install dir

**Login Banner**:
The gradient DEVOPS logo with a live system summary, shown when an interactive shell starts and at the end of an install run.
_Avoid_: MOTD, splash, welcome screen

**User-local Install**:
Placing a Tool in `~/.local/bin` because sudo is unavailable.
_Avoid_: Rootless install, portable install
