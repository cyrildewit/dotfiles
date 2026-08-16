# dotfiles
My dotfiles and personal preferences managed using Chezmoi

## Install scripts

Machine setup lives in `install/<os>/...` as plain, standalone shell scripts.
chezmoi runs them through thin shims in `home/.chezmoiscripts/<os>/`:

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

| Script | Installs | Personal | Work |
| --- | --- | :-: | :-: |
| `command_line_tools.sh` | Xcode Command Line Tools | ✓ | ✓ |
| `homebrew.sh` | Homebrew | ✓ | ✓ |
| `dependencies.sh` | `chezmoi`, `gh`, `git`, `zsh` | ✓ | ✓ |
| `oh_my_posh.sh` | `oh-my-posh` | ✓ | ✓ |
| `docker.sh` | `docker-desktop` | ✓ | ✓ |
| `tools.sh` | `htop`, `zsh-autosuggestions` | ✓ | ✓ |
| `applications.sh` | `1password`, `1password-cli`, `betterdisplay`, `brave-browser`, `claude`, `claude-code`, `ghostty`, `jetbrains-toolbox`, `logi-options+`, `macsyzones`, `spotify`, `todoist-app`, `visual-studio-code` | ✓ | ✓ |
| `fonts.sh` | `font-jetbrains-mono-nerd-font` | ✓ | ✓ |
| `personal/applications.sh` | `proton-drive`, `proton-mail`, `proton-pass` | ✓ | — |
| `optional/dotnet.sh` | `dotnet`, `aspire` | opt-in | opt-in |

Everything above is skipped when it is already installed, including apps that
were installed by hand rather than through Homebrew.

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
