# dotfiles
My dotfiles and personal preferences managed using Chezmoi

## Setting up a new machine

### macOS

```sh
bash -c "$(curl -fsLS https://raw.githubusercontent.com/cyrildewit/dotfiles/main/setup.sh)"
```

`setup.sh` installs Homebrew, installs chezmoi with it, and then runs
`chezmoi init --apply`, which clones this repository, asks its questions and
runs the install scripts. Running it on a machine that is already set up
changes nothing.

chezmoi is installed through Homebrew rather than the standalone installer on
purpose. The standalone installer leaves a binary in `~/.local/bin` that
nothing updates afterwards; letting Homebrew own it means `brew upgrade` keeps
it current, and `dependencies.sh` lists the same formula so the two agree.

### Windows

```powershell
irm https://raw.githubusercontent.com/cyrildewit/dotfiles/main/setup.ps1 | iex
```

`setup.ps1` does the same job with scoop in Homebrew's place: install the
package manager, install chezmoi with it, then `chezmoi init --apply`.

The pipe into `iex` is not just the local spelling of `curl | bash`. A
downloaded `.ps1` carries a mark-of-the-web and will not run under the default
execution policy, so the script has to reach the parser without touching disk.
For the same reason it takes no parameters — there is nothing to bind them to.
`DOTFILES_REPO_URL`, `DOTFILES_BRANCH` and `DOTFILES_DEBUG` are read from the
environment instead, exactly as in `setup.sh`.

scoop rather than winget, although both work on the target machine. scoop
installs per-user and never needs elevation, which is the safer assumption on
an Intune-managed laptop, and it is already the package manager in use there.

The script targets Windows PowerShell 5.1, since that is the only PowerShell on
the machine this was written for.

## Install scripts

Machine setup lives in `install/<os>/...` as plain, standalone scripts, shell
on macOS and PowerShell on Windows. chezmoi runs them through thin shims in
`home/.chezmoiscripts/<os>/`:

```gotmpl
{{ if eq .chezmoi.os "darwin" -}}
{{   include "../install/macos/common/homebrew.sh" }}
{{- end }}
```

`include` resolves from the source dir (`home/`), so `../install/` is the repo
root. On other systems the shim renders empty and chezmoi skips it.

### Machine type

`chezmoi init` asks whether this is a `personal` or a `work` machine and stores
the answer as `machine` in `~/.config/chezmoi/chezmoi.toml`, which stays on the
machine and is never committed. Scripts under `install/macos/personal/` are
gated on it, so a work machine renders them empty and never runs them:

```gotmpl
{{ $machine := dig "machine" "personal" . -}}
{{ if and (eq .chezmoi.os "darwin") (eq $machine "personal") -}}
{{   include "../install/macos/personal/applications.sh" }}
{{- end }}
```

The answer is only asked once. To change it later:

```sh
chezmoi init --prompt
```

The gate reads through `dig` so that a config written before this prompt
existed still applies, defaulting to `personal`.

### Optional stacks

Machine type answers *whose* machine this is. A toolchain is a separate
question, so it gets its own answer rather than being folded into that one:

```gotmpl
{{- $dotnet := promptBoolOnce . "dotnet" "Set up .NET development" false -}}
```

Scripts under `install/macos/optional/` are gated on the result the same way,
and default to off — so `--promptDefaults` installs none of them.

A toolchain earns a prompt when it is heavy, needs more than one step, and is
decided once when the machine is set up. `dotnet` and `aspire` are close to a
gigabyte together and need a tap, so they qualify. Anything that is one quick
`brew install` belongs in `tools.sh` instead, with no question attached.

### What gets installed

#### macOS

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

#### Windows

| Script | Installs | Personal | Work |
| --- | --- | :-: | :-: |
| `scoop.ps1` | scoop | ✓ | ✓ |
| `dependencies.ps1` | `1password-cli`, `chezmoi`, `gh`, `git` | ✓ | ✓ |
| `tools.ps1` | `bruno`, `claude-code`, `nodejs-lts`, `vim` | ✓ | ✓ |
| `fonts.ps1` | `JetBrainsMono-NF`, `JetBrainsMono-NF-Mono`, `JetBrainsMono-NF-Propo` | ✓ | ✓ |

`scoop.ps1` is the counterpart to `homebrew.sh`. On a machine bootstrapped with
`setup.ps1` it does nothing, since that script installed scoop before chezmoi
existed to run anything. It is here for the other way in, a `chezmoi apply` on a
machine that got chezmoi some other way and has no package manager yet.

The other two split the way the macOS scripts do. Something in this repository
breaks without `dependencies.ps1` and nothing breaks without `tools.ps1`.
chezmoi needs git to clone and update the source, and `dot_config/git` is
written for it, so git is a dependency. Nothing here reads bruno, node or vim.
zsh is the one entry on the macOS dependency list with no counterpart here,
since nothing on a Windows host reads the zsh configuration.

`1password-cli` is a dependency in the strict sense. `config-personal.tmpl`
calls `onepasswordRead`, so chezmoi shells out to `op` while rendering that
file, and a machine without it fails the apply. The 1Password desktop app that
sits beside the CLI on macOS has no entry, because no scoop bucket carries a
manifest for it. It is installed machine-wide on the Windows machine already,
which is the copy `onepassword_signer` points at.

scoop has no formula and cask split, so bruno sits among three command-line
packages in `tools.ps1` despite being a GUI app. Once there are several apps
they earn an `applications.ps1` of their own.

Homebrew ships the whole JetBrains Mono Nerd Font family as one cask. The
`nerd-fonts` bucket splits it into three manifests, one per variant, so
`fonts.ps1` lists all three and the family matches on both systems. The cost is
the same zip downloaded three times, since scoop caches per app rather than per
url. The manifests install per user and register the font under `HKCU`, so none
of this needs elevation on Windows 10 1809 or later.

Two buckets beyond the one scoop ships with are in play. `tools.ps1` adds
`extras` for bruno and `fonts.ps1` adds `nerd-fonts`. Cloning a bucket needs
git, which is what makes the order matter. `dependencies.ps1` is a
`run_once_before_` script, so it runs ahead of every unprefixed one whatever the
numbers say.

One wrinkle has no macOS equivalent. The scoop installer writes the shims to the
user PATH, and the running chezmoi never re-reads that, so a scoop installed
mid-apply is not on PATH for the scripts that follow. Any script that needs
scoop has to prepend `~/scoop/shims` itself, the way `Enable-Scoop` does.
`setup.ps1` avoids the problem by enabling scoop before chezmoi starts.

### When scripts run

The filename prefix picks the hook:

| prefix | runs |
| --- | --- |
| `run_` | on every `chezmoi apply` |
| `run_once_` | once per unique script content |
| `run_onchange_` | whenever the script content changes |

Add `before_` or `after_` to place a script around the dotfile updates
(`run_once_before_`, `run_after_`, …). Without either, it runs in between,
interleaved with the files. Scripts execute in ASCII order of their names —
that is what the numeric prefixes are for.

## Application config

### MacsyZones

Layouts and settings are synced. Per-machine state is not, since it keys on
display IDs and Space numbers that mean nothing on another Mac.

| File | Synced |
| --- | :-: |
| `UserLayouts.json` | ✓ |
| `AppSettings.json` | ✓ |
| `SpaceLayoutPreferences.json` | — |
| `UpdateState.json` | — |
| `OnboardingState.json` | — |

The canonical copies live in `home/dot_config/macsyzones/` and are symlinked
into `~/Library/Application Support/MeowingCat.MacsyZones/`, the same adapter
the shared skills pool uses. MacsyZones writes through the symlink, so zones
drawn in its UI land in the working tree.

Do not give that directory the `exact_` attribute. It would delete the unsynced
files above.
