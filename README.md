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
a machine that is already set up changes nothing.

## What gets installed

### macOS

| Script                     | Installs                                                                                                                                                                                                           | Personal |  Work  |
|----------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|:--------:|:------:|
| `command_line_tools.sh`    | Xcode Command Line Tools                                                                                                                                                                                           |    ✓     |   ✓    |
| `homebrew.sh`              | Homebrew                                                                                                                                                                                                           |    ✓     |   ✓    |
| `dependencies.sh`          | `chezmoi`, `gh`, `git`, `zsh`                                                                                                                                                                                      |    ✓     |   ✓    |
| `oh_my_posh.sh`            | `oh-my-posh`                                                                                                                                                                                                       |    ✓     |   ✓    |
| `docker.sh`                | `docker-desktop`                                                                                                                                                                                                   |    ✓     |   ✓    |
| `tools.sh`                 | `ccusage`, `eza`, `htop`, `zsh-autosuggestions`                                                                                                                                                                    |    ✓     |   ✓    |
| `applications.sh`          | `1password`, `1password-cli`, `betterdisplay`, `brave-browser`, `claude`, `claude-code`, `ghostty`, `jetbrains-toolbox`, `logi-options+`, `macsyzones`, `obsidian`, `spotify`, `todoist-app`, `visual-studio-code` |    ✓     |   ✓    |
| `fonts.sh`                 | `font-jetbrains-mono-nerd-font`                                                                                                                                                                                    |    ✓     |   ✓    |
| `personal/applications.sh` | `proton-drive`, `proton-mail`, `proton-pass`                                                                                                                                                                       |    ✓     |   —    |
| `optional/dotnet.sh`       | `dotnet`, `aspire`                                                                                                                                                                                                 |  opt-in  | opt-in |

Everything above is skipped when it is already installed, including apps that
were installed by hand rather than through Homebrew.

### Windows

| Script             | Installs                                                              | Personal | Work |
|--------------------|-----------------------------------------------------------------------|:--------:|:----:|
| `scoop.ps1`        | scoop                                                                 |    ✓     |  ✓   |
| `dependencies.ps1` | `1password-cli`, `chezmoi`, `gh`, `git`                               |    ✓     |  ✓   |
| `tools.ps1`        | `claude-code`, `eza`, `nodejs-lts`, `vim`                             |    ✓     |  ✓   |
| `npm-tools.ps1`    | `@colbymchenry/codegraph`, `ccusage`, through npm                     |    ✓     |  ✓   |
| `applications.ps1` | `brave`, `bruno`, `claude`, `jetbrains-toolbox`, `vscode`             |    ✓     |  ✓   |
| `onepassword.ps1`  | `AgileBits.1Password`, through winget                                 |    ✓     |  ✓   |
| `fonts.ps1`        | `JetBrainsMono-NF`, `JetBrainsMono-NF-Mono`, `JetBrainsMono-NF-Propo` |    ✓     |  ✓   |

`applications.ps1` cannot skip an application that was installed by hand, since
Windows has no equivalent of `/Applications` to check: an installer can land in
Program Files or under `LOCALAPPDATA`, per-machine or per-user. scoop installs
its own copy alongside, which for a browser means a second profile.

The repository layout and the conventions behind it are in [`docs/`](docs/).
