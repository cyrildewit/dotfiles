# dotfiles

My dotfiles and personal preferences managed using [chezmoi](https://www.chezmoi.io).

## Setting up a new machine

### macOS

```sh
bash -c "$(curl -fsLS https://raw.githubusercontent.com/cyrildewit/dotfiles/main/setup.sh)"
```

### Windows

```powershell
irm https://raw.githubusercontent.com/cyrildewit/dotfiles/main/setup.ps1 | iex
```

Both scripts install a package manager (Homebrew on macOS, scoop on Windows),
install chezmoi with it, then run `chezmoi init --apply`, which clones this
repository, asks its questions and runs the install scripts. Running either on
a machine that is already set up changes nothing. Both read
`DOTFILES_REPO_URL`, `DOTFILES_BRANCH` and `DOTFILES_DEBUG` from the
environment rather than taking parameters; the header comment in each explains
why, along with the rest of the choices behind it.

`chezmoi init` asks whether this is a `personal` or a `work` machine, and asks
once for each optional toolchain (`dotnet`). The answers land in
`~/.config/chezmoi/chezmoi.toml`, which stays on the machine and is never
committed. Optional toolchains default to off, so `--promptDefaults` installs
none of them. To answer the questions again:

```sh
chezmoi init --prompt
```

## What gets installed

### macOS

| Script | Installs | Personal | Work |
| --- | --- | :-: | :-: |
| `command_line_tools.sh` | Xcode Command Line Tools | ✓ | ✓ |
| `homebrew.sh` | Homebrew | ✓ | ✓ |
| `dependencies.sh` | `chezmoi`, `gh`, `git`, `zsh` | ✓ | ✓ |
| `oh_my_posh.sh` | `oh-my-posh` | ✓ | ✓ |
| `docker.sh` | `docker-desktop` | ✓ | ✓ |
| `tools.sh` | `eza`, `htop`, `zsh-autosuggestions` | ✓ | ✓ |
| `applications.sh` | `1password`, `1password-cli`, `betterdisplay`, `brave-browser`, `claude`, `claude-code`, `ghostty`, `jetbrains-toolbox`, `logi-options+`, `macsyzones`, `obsidian`, `spotify`, `todoist-app`, `visual-studio-code` | ✓ | ✓ |
| `fonts.sh` | `font-jetbrains-mono-nerd-font` | ✓ | ✓ |
| `personal/applications.sh` | `proton-drive`, `proton-mail`, `proton-pass` | ✓ | — |
| `optional/dotnet.sh` | `dotnet`, `aspire` | opt-in | opt-in |

Everything above is skipped when it is already installed, including apps that
were installed by hand rather than through Homebrew.

### Windows

| Script | Installs | Personal | Work |
| --- | --- | :-: | :-: |
| `scoop.ps1` | scoop | ✓ | ✓ |
| `dependencies.ps1` | `1password-cli`, `chezmoi`, `gh`, `git` | ✓ | ✓ |
| `tools.ps1` | `claude-code`, `eza`, `nodejs-lts`, `vim` | ✓ | ✓ |
| `applications.ps1` | `brave`, `bruno`, `claude`, `jetbrains-toolbox` | ✓ | ✓ |
| `onepassword.ps1` | `AgileBits.1Password`, through winget | ✓ | ✓ |
| `fonts.ps1` | `JetBrainsMono-NF`, `JetBrainsMono-NF-Mono`, `JetBrainsMono-NF-Propo` | ✓ | ✓ |

`applications.ps1` cannot skip an application that was installed by hand, since
Windows has no equivalent of `/Applications` to check: an installer can land in
Program Files or under `LOCALAPPDATA`, per-machine or per-user. scoop installs
its own copy alongside, which for a browser means a second profile.

## Layout

| Path | |
| --- | --- |
| `home/` | the chezmoi source directory, per `.chezmoiroot` |
| `home/.chezmoiscripts/<os>/` | shims that include the install scripts |
| `install/<os>/` | machine setup, shell on macOS and PowerShell on Windows |
| `scripts/<os>/` | helpers a `run_after_` shim includes |
| `docs/` | conventions and caveats that nothing here enforces |

The install scripts are plain and standalone. chezmoi runs them through a shim:

```gotmpl
{{ if eq .chezmoi.os "darwin" -}}
{{   include "../install/macos/common/homebrew.sh" }}
{{- end }}
```

`include` resolves from the source directory (`home/`), so `../install/` is the
repo root. On another operating system, or when a prompt answer gates it, the
shim renders empty and chezmoi skips it. The filename prefix picks the hook and
the numeric prefix orders it, both as
[chezmoi documents](https://www.chezmoi.io/reference/target-types/#scripts).

Each install script opens with a header comment covering what it installs and
why it is a script of its own rather than a line in another list.

## Further reading

- [Where git repositories live](docs/repos.md)
- [MacsyZones](docs/macsyzones.md)
