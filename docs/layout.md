# Layout

| Path                         |                                                         |
|------------------------------|---------------------------------------------------------|
| `home/`                      | the chezmoi source directory, per `.chezmoiroot`        |
| `home/.chezmoiscripts/<os>/` | shims that include the install scripts                  |
| `install/<os>/`              | machine setup, shell on macOS and PowerShell on Windows |
| `scripts/<os>/`              | helpers a `run_after_` shim includes                    |
| `docs/`                      | conventions and caveats that nothing here enforces      |

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
