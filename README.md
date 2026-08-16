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
