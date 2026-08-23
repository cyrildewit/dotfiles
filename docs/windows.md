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

Feature parity with macOS is explicitly *not* the goal of the first pass. The
work is staged so that a working, boring Windows setup arrives early and the
comforts arrive later:

- **Phase 1 — make the repository *safe* on Windows.** Every macOS-shaped file
  either renders empty or is ignored, so an apply writes only what is
  genuinely portable and leaves everything else alone. None of this needs to
  know anything about the laptop, so **all of it can be done today, from the
  Mac.**
- **Phase 2 — get it *running* on the laptop.** Probe the machine, settle only
  the decisions that block an apply, then apply. What lands is git config, the
  global gitignore, and Claude configuration.
- **Phase 3 — parity, as and when it is wanted.** The PowerShell profile,
  prompt, aliases, the skills linker, `setup.ps1`. None of it blocks anything;
  each piece can land on its own.

The point of drawing the line after phase 2 is that nothing in phase 3 is
load-bearing. A Windows machine with managed git and Claude config but a stock
PowerShell prompt is a perfectly good machine. It just is not a pretty one yet.

### Why the shell does not port

zsh does not exist on native Windows, and PowerShell is not a POSIX shell — it
is a different language passing objects rather than text. `.zshrc`,
`.zprofile` and `.aliases` are not *unsupported* there so much as meaningless:
nothing would ever read them. Ignoring them in step 2 is the accurate
description of reality, not a compromise.

The counterpart is `$PROFILE`, a separate artefact written from scratch in
phase 3.

---

# Phase 1 — Make it safe on Windows

Repository-only changes. Nothing is applied to the laptop. All of it can be
reviewed as an ordinary diff and validated by CI.

## Step 1 — Gate the shared-skills script ✅

`home/.chezmoiscripts/run_after_40-link-shared-skills.sh` was the only script
in the repository with no OS gate, and it is a bare `.sh`. chezmoi has no
default interpreter for `.sh` on Windows, so it cannot execute it — that fails
the whole apply, before anything else gets a chance to go wrong.

Rather than wrap the body in a template conditional, it was restructured onto
the same shim pattern the `install/` scripts already use. The body stays plain
shell — lintable, no Go template syntax in it — and the guard lives in the
shim:

```
scripts/macos/link-shared-skills.sh                                   plain bash
scripts/windows/link-shared-skills.ps1                                plain PowerShell
home/.chezmoiscripts/macos/run_after_40-link-shared-skills.sh.tmpl    shim, carries the guard
home/.chezmoiscripts/windows/run_after_40-link-shared-skills.ps1.tmpl shim, carries the guard
```

The shim directory mirrors the body directory, the same way
`.chezmoiscripts/macos/*.tmpl` include from `install/macos/`. Each shim guards
on its own OS and `include`s its body. chezmoi picks the interpreter from the
file extension, so only one of the two ever renders non-empty and neither needs
to know about the other.

The Windows body uses junctions rather than symlinks, since a junction needs no
privilege and every pool entry is a directory. It also deletes links through
`[IO.Directory]::Delete`, because `Remove-Item` can follow a junction and delete
what it points at, which here would be skills inside the source tree.

`run_after_` rather than `run_once_`, so the rename invalidates no state hash.

Verified: the macOS render is identical to the original script apart from one
trailing newline, which the existing `install/` shims add too. The simulated
Windows render is a single newline, and a whitespace-only script is skipped.

`.chezmoiignore` was tested as an alternative and rejected — it does not apply
to scripts. A bare name and a glob both still ran it.

**Done when:** ✅ renders empty on Windows, unchanged on macOS.

## Step 2 — Grow the Windows ignore list

`home/.chezmoitemplates/chezmoiignore.d/windows` currently ignores only
`.config/homebrew`. A Windows host runs neither zsh nor Ghostty, and cannot
necessarily create symlinks at all, so add:

```
.zshrc
.zprofile
.aliases
.config/ghostty
.agents
```

The first four are inert on Windows — nothing reads them. `.agents` is the
one that actually matters: `exact_dot_agents/exact_skills/symlink_*` are real
symlink entries, and creating a symlink on Windows needs Developer Mode or
elevation. Without this line an unprivileged laptop fails the apply, which
means phase 1 is not safe without it.

Ignoring `.agents` also makes the shared-skills linker a no-op there, since
its pool would not exist — so the two halves stay consistent until phase 3
brings both back together.

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

Whether it ever needs a Windows branch is settled in 7c, and the likely answer
is no. This step is deliberately only the safe half.

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
Windows signing path deferred to 7b — unsigned commits there are fine to start
with.

The 1Password multi-account failure described in 7b is a *macOS* bug, live
today, in this same file. Fix it here rather than carrying it forward.

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

Grow it as the later phases land.

**Done when:** the workflow is green, and the macOS workflow still is too.

## After phase 1

The repository applies safely on Windows. What lands is git config, the global
gitignore, and the Claude configuration. What is skipped is everything
macOS-shaped. Nothing on the laptop gets overwritten.

That is the point at which running `chezmoi init` against the real machine
stops being risky.

---

# Phase 2 — Get it running on the laptop

Everything below needs facts about the laptop, so it starts with a probe.

The goal here is a machine that applies cleanly and gives you managed git and
Claude configuration. Nothing more. Anything that can wait is in phase 3, and
step 7 marks which decisions actually block an apply.

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

What each answer decides:

| Probe | If | Then |
| --- | --- | --- |
| `$PSVersionTable` | `7.x` | Profile at `Documents\PowerShell\`. Modern syntax available. |
| | `5.1` | Profile at `Documents\WindowsPowerShell\`. Older PSReadLine, and UTF‑8 needs setting explicitly for prompt glyphs. |
| `GetFolderPath('MyDocuments')` | `C:\Users\<you>\Documents` | The profile can be a plain managed file at a fixed path. |
| | anything under `OneDrive` | No fixed offset from `~` exists. Step 8 needs the stub pattern below. |
| `AllowDevelopmentWithoutDevLicense` | `1` | `symlink_` entries work. Keep them. |
| | empty / `0` | chezmoi cannot create symlinks. Junctions or nothing. |
| `~/.gitconfig` | exists | It wins over the managed `~/.config/git/config` on conflicts. Decide whether to fold it in or delete it. |
| `~/.ssh/config` | exists | Left untouched by phase 1. Decide whether to adopt it. |

## Step 7 — Settle the open questions

Only one of these blocks an apply. The rest can be answered with "not yet".

| | Blocks phase 2? | |
| --- | :-: | --- |
| 7a git identity | **yes** | It is most of what actually lands. |
| 7b commit signing | no | Unsigned commits on the work machine are fine to start. The macOS half is a live bug and belongs in step 4 regardless. |
| 7c ssh agent | no | Phase 1 leaves `~/.ssh/config` alone; verify at apply time. |
| 7d symlinks vs junctions | no | Step 2 ignores `.agents` on Windows, deferring this wholesale to phase 3. |
| 7e eza | no | Cosmetic. |

### 7a — Git identity on a work machine

`.chezmoi.toml.tmpl` hardcodes the personal name and email for every machine,
and `config.tmpl` writes them as `[user]`. The `includeIf` override points at
`~/Code/ArchipelAcademy`, and the file it includes is empty.

Three ways out, in rough order of preference:

1. **Prompt for the work identity**, gated on `machine == work`, alongside the
   existing `promptChoiceOnce`. The laptop then gets the right address
   globally, which is the one you commit with most there.
2. **Keep personal global and fill in the `includeIf`.** Note this needs the
   work checkout path on Windows, which will not be `~/Code/ArchipelAcademy` —
   so it needs a prompt anyway, and you get the wrong default until you are
   inside the right directory.
3. **Ignore `.config/git` on work entirely** and leave the laptop as it is.

Whatever is chosen, the `~/.gitconfig` precedence trap from step 6 has to be
resolved or the managed file will be half-ignored.

### 7b — Commit signing on Windows

Two separate problems, one of which is already live.

**The account ambiguity is breaking macOS today.** `chezmoi apply` currently
fails on the Mac:

```
[ERROR] multiple accounts found. Use the --account flag or set OP_ACCOUNT
chezmoi: .config/git/config-personal: ... error calling onepasswordRead
```

`onepasswordRead` at `config-personal.tmpl:21` has no way to pick between the
accounts now signed in. It takes an optional second argument for exactly this.
That fix belongs in step 4, not here — it is not Windows-specific.

**The signing program path is Windows-specific.** `op-ssh-sign.exe` sits under
`%LOCALAPPDATA%\1Password\app\<version>\`, and that version number moves. Options:
pin it and accept the breakage on upgrade, resolve it at apply time in a
template, or leave commits unsigned on the work machine. Confirm the actual
path during the probe.

### 7c — SSH agent

1Password on Windows serves its agent over the *standard* OpenSSH named pipe
(`\\.\pipe\openssh-ssh-agent`), so Windows' own `ssh.exe` finds it with no
configuration at all. Verify, but if it holds, step 3's "render empty on
Windows" is not a stopgap — it is the final answer.

The catch is which `ssh` git actually invokes. Git for Windows bundles an
MSYS2 `ssh` that historically cannot talk to a Windows named pipe. If commits
authenticate from PowerShell but fail from git, the fix is pointing git at the
system binary:

```
[core]
    sshCommand = C:/Windows/System32/OpenSSH/ssh.exe
```

That is a managed git config line, so it lands in `config.tmpl` gated on
`windows` — worth verifying early, because it is easy to misdiagnose.

### 7d — Skill symlinks vs junctions

If Developer Mode is off, `New-Item -ItemType SymbolicLink` needs elevation
but `-ItemType Junction` does not, and every pool entry is a directory — so
the linker script has a clean way out.

That only covers the script. chezmoi's own `symlink_` entries under
`exact_dot_agents/exact_skills/` create real symlinks and would still fail.
Options: ignore those on Windows and let the `.ps1` build both halves with
junctions, or require Developer Mode. The first keeps the machine unprivileged.

### 7e — eza

On the machine or not. Decides step 2's judgment call about `.config/eza`.

## Step 8 — Dry-run and apply

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
and a fresh PowerShell session opens without complaint.

At this point the laptop is done, in the sense that matters. Everything below
is optional and can be picked up whenever it starts to annoy you.

---

# Phase 3 — Parity, when it is wanted

Nothing here blocks anything. Each item stands alone, so they can land in any
order, months apart, or never.

## Step 9 — Add the PowerShell profile

The one genuinely new artefact. Most of the rest already ported in phase 2,
because git on Windows reads `~/.config/git/config` and Claude Code reads
`~/.claude`.

| Source | Windows host |
| --- | --- |
| `dot_config/git/*` | Carries over. Identity, signing program and `sshCommand` differ. |
| `dot_claude/*` | Carries over as-is. |
| `dot_config/git/ignore` | Carries over as-is. |
| `dot_ssh/config` | Likely nothing needed — see 7c. |
| `dot_config/agents` + `symlink_*` | Depends on 7d. |
| `dot_zshrc` / `dot_zprofile` / `dot_aliases` | Not applicable. The profile replaces them. |
| `dot_config/ghostty`, `dot_config/homebrew` | Not applicable. |

### The profile path problem

chezmoi maps a source path to a target path at a fixed offset from `~`. That
works only if `Documents` is where Windows puts it by default. Under OneDrive
redirection the real path contains the tenant name, which is machine-specific
and has no business in this repository.

The robust answer works either way: manage the real profile at a stable path,
and have a `run_once_` `.ps1` write a one-line stub at whatever `$PROFILE`
resolves to at runtime.

```
home/dot_config/powershell/profile.ps1        managed, stable path
run_once_after_...-link-powershell-profile.ps1.tmpl   writes the stub
```

The stub is just `. "$HOME/.config/powershell/profile.ps1"`. Because the script
resolves `$PROFILE` itself, OneDrive redirection and the 5.1-vs-7 path
difference both stop mattering. Worth doing even if the probe comes back clean,
since it costs one small script and removes a whole class of breakage.

### What goes in it

The zsh configuration, translated. Not everything has an equivalent.

| `.zshrc` / `.aliases` | PowerShell |
| --- | --- |
| `oh-my-posh init zsh` | `oh-my-posh init pwsh \| Invoke-Expression` (verify the shell name on 5.1) |
| `zsh-autosuggestions` | PSReadLine — `Set-PSReadLineOption -PredictionSource History`. Needs PSReadLine 2.1+, which 5.1 may not ship. |
| `alias l="eza -la ..."` | `function l { eza -la ... }` — PowerShell aliases cannot carry arguments, so these become functions. |
| `.NET telemetry opt-outs` | Same variables, `$env:DOTNET_CLI_TELEMETRY_OPTOUT = 1`. More relevant here than on the Mac. |
| `XDG_*` exports | No Windows convention. Set only what a specific tool actually reads. |

`dot_aliases` is the shared shell layer today and PowerShell cannot source it.
Either keep the two in sync by hand or accept the duplication — there is no
clean third option.

## Step 10 — The skills linker's Windows half

Following the shape step 1 set up:

```
scripts/windows/link-shared-skills.ps1                           plain PowerShell
home/.chezmoiscripts/run_after_40-link-shared-skills.ps1.tmpl    shim, guards on eq "windows"
```

This also means undoing step 2's `.agents` ignore, so it is two changes that
have to land together: the symlink entries become creatable again *and* the
linker gains a Windows body. Doing one without the other leaves a half-wired
pool.

Symlink or junction is settled by 7d. Any new Windows-side script should be
`.ps1` — chezmoi picks the interpreter from the extension and runs those
natively, which is exactly why the `.sh` half needed gating in step 1.

## Step 11 — `setup.ps1`

The first step that installs anything, and the reason it comes last.

`setup.sh` already points Git Bash users at a `setup.ps1` that does not exist
(`setup.sh:141`), so that message becomes true rather than aspirational.

Three things it has to get right that the macOS path does not:

- **Package manager.** winget ships with Windows 11 and needs no bootstrap of
  its own, which makes it the closer analogue to Homebrew here. Corporate
  policy sometimes restricts it, so confirm on the actual laptop before
  committing to it; scoop is the fallback and installs per-user.
- **Execution policy.** A downloaded script will not run under the default
  policy. The documented one-liner has to be the `irm ... | iex` form, which
  sidesteps it, rather than the `curl | bash` shape used on macOS.
- **No `bootstrap_os` branch.** Unlike `setup.sh`, this file only ever runs on
  one OS, so it needs none of that structure.

Same job as the macOS path otherwise: acquire chezmoi, then
`chezmoi init --apply`. The existing reasoning — let a package manager
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
