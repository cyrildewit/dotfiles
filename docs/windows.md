# Porting the dotfiles to Windows

A working plan for bringing this repository to a Windows work laptop. Written
to be worked through by hand, one step at a time. Delete it once the port has
landed and the README covers the result.

WSL is out of scope. chezmoi would see it as a separate machine anyway —
separate home directory, separate clone, separate `chezmoi.toml` — so nothing
here forecloses doing it later.

macOS stays exactly as it is. Nothing in this plan should change what a
personal Mac gets.

## The split

The work divides cleanly in two, and the halves have very different
prerequisites:

- **Phase 1 — make the repository *safe* on Windows.** Every macOS-shaped file
  either renders empty or is ignored, so an apply writes only what is
  genuinely portable and leaves everything else alone. None of this needs to
  know anything about the laptop, so **all of it can be done today, from the
  Mac.**
- **Phase 2 — make the repository *complete* on Windows.** A PowerShell
  profile, the SSH agent, the skill symlinks, the git identity. Every one of
  these depends on a fact about that specific machine, so phase 2 starts with
  a probe.

The value of that split is that after phase 1 you can safely run a real apply
on the laptop and have it be boring. It writes git config and Claude config,
touches nothing else, and breaks nothing.

---

# Phase 1 — Make it safe on Windows

Repository-only changes. Nothing is applied to the laptop. All of it can be
reviewed as an ordinary diff and validated by CI.

## Step 1 — Gate the shared-skills script

`home/.chezmoiscripts/run_after_40-link-shared-skills.sh` is the only script
in the repository with no OS gate, and it is a bare `.sh`. chezmoi has no
default interpreter for `.sh` on Windows, so it cannot execute it — this fails
the whole apply, before anything else gets a chance to go wrong.

Rename it to `run_after_40-link-shared-skills.sh.tmpl` and guard on OS, the
same way `.chezmoiscripts/macos/*.tmpl` already do. Because it is a `run_after_`
script rather than `run_once_`, there is no state hash to invalidate.

**Done when:** the file renders empty on Windows and unchanged on macOS.

## Step 2 — Grow the Windows ignore list

`home/.chezmoitemplates/chezmoiignore.d/windows` currently ignores only
`.config/homebrew`. A Windows host runs neither zsh nor Ghostty, so add:

```
.zshrc
.zprofile
.aliases
.config/ghostty
```

`.config/eza` is a judgment call — eza has Windows builds, but if it is not
going on that machine the theme file is just clutter. Either is defensible.

**Done when:** those targets no longer appear in a Windows apply.

## Step 3 — Gate the SSH config to macOS

`home/dot_ssh/config.tmpl` hardcodes the macOS 1Password agent socket with no
OS guard. Applied to Windows it would overwrite `%USERPROFILE%\.ssh\config`
with a path that means nothing there — the single biggest breakage risk in the
repository.

Wrap the existing block in a `darwin` guard. On Windows it then renders empty,
chezmoi skips the file entirely, and whatever SSH config is already on that
laptop is left untouched.

The Windows branch gets filled in during phase 2, once we know whether it
needs one at all. This step is deliberately only the safe half.

**Done when:** `~/.ssh/config` is absent from a Windows apply, and unchanged
on macOS.

## Step 4 — Gate the commit signing program to macOS

`home/dot_config/git/config-personal.tmpl` is guarded on `lookPath "op"`, which
proves the 1Password CLI exists but says nothing about the OS. The block it
guards writes `program = /Applications/1Password.app/Contents/MacOS/op-ssh-sign`.
1Password CLI is available on Windows, so on a laptop that has it the guard
opens and git gets pointed at a macOS path — commit signing then fails on
every commit.

Narrow the guard to `darwin` as well. Same as step 3: the safe half now, the
Windows signing path in phase 2.

**Done when:** the file renders empty on Windows, and unchanged on macOS.

## Step 5 — Prove it with CI

`.github/workflows/macos.yaml` is the model. A `windows.yaml` on
`windows-latest` gives a real Windows test bed at zero risk to the work
laptop — which matters, because steps 1–4 cannot otherwise be verified from a
Mac. `.chezmoi.os` is not something a template can be tricked about.

Start it as a smoke test rather than a copy of the macOS job: install chezmoi
on the runner directly (winget or scoop — no `setup.ps1` needed yet), run
`chezmoi init --apply` with the prompt answers piped in, and assert that

- the apply succeeds at all,
- `~/.config/git/config` and `~/.claude/settings.json` exist,
- `~/.ssh/config`, `~/.zshrc` and `~/.config/ghostty/config` do **not**,
- a second apply leaves `chezmoi status --exclude=scripts` empty.

Grow it as phase 2 lands.

**Done when:** the workflow is green, and the macOS workflow still is too.

## After phase 1

The repository applies safely on Windows. What lands is git config, the global
gitignore, and the Claude configuration. What is skipped is everything
macOS-shaped. Nothing on the laptop gets overwritten.

That is the point at which running `chezmoi init` against the real machine
stops being risky.

---

# Phase 2 — Make it complete on Windows

Everything below needs facts about the laptop, so it starts with a probe.

## Step 6 — Probe the machine

```powershell
$PSVersionTable.PSVersion
$PROFILE
[Environment]::GetFolderPath('MyDocuments')
Get-ChildItem $env:USERPROFILE -Force -Name
Get-Content "$env:USERPROFILE\.gitconfig" -EA SilentlyContinue
Get-Content "$env:USERPROFILE\.ssh\config" -EA SilentlyContinue
(Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock' -EA SilentlyContinue).AllowDevelopmentWithoutDevLicense
```

Watching for:

- **Is `MyDocuments` redirected into OneDrive?** Common on corporate laptops.
  It moves `$PROFILE` off any fixed offset from the home directory, which
  changes how step 8 has to be written.
- **PowerShell 7 or Windows PowerShell 5.1?** Different profile paths
  (`Documents\PowerShell\` vs `Documents\WindowsPowerShell\`) and different
  available syntax.
- **Is Developer Mode on?** The last command returns `1` if so. Decides
  whether `exact_dot_agents/exact_skills/symlink_*` can work at all.
- **What git and ssh config already exists.**

## Step 7 — Settle the open questions

| Question | Options |
| --- | --- |
| Git identity on a work machine | Prompt for work name/email gated on `machine == work`; or keep personal global with a per-directory `includeIf`; or leave git unmanaged on work. |
| Commit signing on Windows | Point `gpg.ssh.program` at the Windows `op-ssh-sign.exe`, or leave commits unsigned there. |
| SSH agent | Verify whether 1Password on Windows serves the standard OpenSSH named pipe (`\\.\pipe\openssh-ssh-agent`), in which case the config may need nothing at all. |
| Skill symlinks | Developer Mode on → keep `symlink_` entries. Off → convert to a copy or a script, or keep them ignored on Windows. |
| eza | On the machine or not — decides step 2's judgment call. |

Record the answers here as they are settled.

## Step 8 — Add the PowerShell profile

The one genuinely new artefact. Most of the rest already ports, because git on
Windows reads `~/.config/git/config` and Claude Code reads `~/.claude`.

| Source | Windows host |
| --- | --- |
| `dot_config/git/*` | Carries over. Identity and signing program differ. |
| `dot_claude/*` | Carries over as-is. |
| `dot_config/git/ignore` | Carries over as-is. |
| `dot_ssh/config` | Structure carries over, agent differs. |
| `dot_config/agents` + `symlink_*` | Depends on Developer Mode. |
| `dot_zshrc` / `dot_zprofile` / `dot_aliases` | Not applicable. The profile replaces them. |
| `dot_config/ghostty`, `dot_config/homebrew` | Not applicable. |

Worth deciding while writing it: `dot_aliases` is the shared shell layer
today, and PowerShell needs its own. Either the two are kept in sync by hand,
or the profile is simply written independently and the duplication accepted.

Any new Windows-side script should be `.ps1` — chezmoi runs those natively.

## Step 9 — Dry-run and apply on the laptop

```powershell
chezmoi init https://github.com/cyrildewit/dotfiles.git   # clone + prompts only
chezmoi status
chezmoi diff
chezmoi apply --dry-run --verbose
```

`chezmoi init` without `--apply` clones to `%USERPROFILE%\.local\share\chezmoi`
and writes `%USERPROFILE%\.config\chezmoi\chezmoi.toml`. It touches nothing
else and runs no scripts. To abandon, delete those two directories.

Use `--branch` if the work is not on `main` yet.

This is the machine with config worth protecting, so read the whole diff
rather than skimming it. Then `chezmoi apply`.

**Done when:** a second apply leaves `chezmoi status --exclude=scripts` empty,
and a fresh PowerShell session behaves.

## Step 10 — `setup.ps1`

The first step that installs anything, and the reason it comes last.

`setup.sh` already points Git Bash users at a `setup.ps1` that does not exist
(`setup.sh:141`). Same job as the macOS path, in PowerShell: acquire chezmoi,
then `chezmoi init --apply`. The existing reasoning — let a package manager
own the binary so upgrades keep working — should carry over to whichever of
winget or scoop is chosen.

Once it exists, rewrite step 5's workflow to bootstrap through it, the way
`macos.yaml` runs `setup.sh` exactly as the README documents.

---

## Reference — what the repository does today

Traced against the current source tree. The Windows column is what would
happen with no changes at all.

| Target | Windows today | Notes |
| --- | --- | --- |
| `run_after_40-link-shared-skills.sh` | **fails the apply** | Bare `.sh`, no OS gate, no interpreter on Windows. |
| `~/.ssh/config` | **overwrites** | Hardcodes the macOS 1Password socket. |
| `~/.config/git/config-personal` | **breaks signing** if `op` is installed | Guarded on `lookPath "op"`, not on OS. |
| `~/.claude/settings.json`, `CLAUDE.md`, `rules/` | overwrites | Portable, but overwrites whatever is there. |
| `~/.config/git/config` | written | Sets the *personal* name and email as global identity. |
| `~/.config/git/ignore` | written | Fine as-is. |
| `~/.zshrc`, `~/.aliases` | written | Useless on the host. |
| `~/.config/ghostty/config`, `~/.config/eza/theme.yml` | written | Useless on the host. |
| `~/.zprofile` | skipped | The `stat "/opt/homebrew/bin/brew"` guard renders it empty. |
| `~/.config/homebrew` | skipped | Already in `chezmoiignore.d/windows`. |
| `.chezmoiscripts/macos/*` | skipped | Guarded on `darwin`. |
| `exact_dot_agents/exact_skills/symlink_*` | needs Developer Mode | Fails without it. |

Two other things to know before starting:

- Git reads *both* `~/.gitconfig` and `~/.config/git/config`, with
  `~/.gitconfig` winning on conflicts. If the laptop already has a
  `~/.gitconfig`, the managed XDG file will be quietly half-ignored rather
  than take effect.
- `.chezmoi.toml.tmpl` hardcodes the personal name and email for every
  machine, and the work override (`config-work-archipel-academy.tmpl`) is an
  empty file that does nothing. There is already a `machine` prompt answering
  personal-vs-work that nothing hangs off yet.
