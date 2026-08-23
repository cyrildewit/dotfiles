# Where git repositories live

One layout for every machine, so that a path can be derived from a remote URL
and nothing has to be decided at clone time.

> A clone's path mirrors its remote's namespace: `~/Code/<owner>/<repo>`.
> Everything that has no remote, or belongs to someone else, lives under a
> `_`-prefixed sibling.

```
~/Code/
├── cyrildewit/          github.com/cyrildewit/*
├── archipelacademy/     dev.azure.com/archipelacademy/*
├── _external/           clones of repositories owned by someone else
│   └── microsoft/aspire-samples
└── _sandbox/            no remote, no rule, no naming convention
```

The root is `~/Code` on every machine — the same literal path, not a
per-machine variable. macOS and Windows filesystems are both
case-insensitive, so the root keeps its capital `C` while the segments below
it are whatever the remote URL says, which in practice is lowercase.

## Why owner and repository, and nothing else

The layout exists to make one function total: given a URL, there is exactly
one path, and it needs no lookup table, no prompt and no judgement.

A host segment (`~/Code/github.com/...`, the `ghq` convention) was rejected on
path length. The work laptop has `LongPathsEnabled = 0` and around 157 .NET
repositories, and `MAX_PATH` is a real ceiling there:

```
C:\Users\CyrildeWit\Code\dev.azure.com\archipelacademy\...\Campus-FE    87 chars
C:\Users\CyrildeWit\Code\archipelacademy\Campus-FE                      50 chars
```

Two hosts sharing an owner name would collide. That is accepted: it has not
happened, and it would be visible immediately rather than silently.

## Reserved directories

`_external` and `_sandbox` are separate because they have opposite lifecycles.
`_external` is entirely reconstructible — every byte can be re-cloned, so it
can be deleted on a whim and is worth excluding from any backup. `_sandbox`
holds the only data in the tree that exists nowhere else. Merged into one
directory, neither could be safely bulk-deleted nor safely bulk-skipped.

That distinction is recorded intent, not configuration. No backup rule acts on
it yet.

`_sandbox` has no internal structure on purpose. It is the pressure-release
valve for the invariant below, and a naming convention there would recreate
the problem it exists to absorb.

The leading `_` is load-bearing. GitHub usernames and Azure DevOps
organisation names are alphanumeric-plus-hyphen, so `_` cannot collide with a
real owner — without it, `github.com/sandbox/thing` would compute a path
straight into the reserved directory. That gives an invariant worth stating,
because it is what makes the tree safe to enumerate or re-clone later:

> Every directory at depth 1 without a `_` prefix is an owner, and everything
> beneath it is derivable from a remote URL.

## Azure DevOps has one segment too many

Azure DevOps namespaces are `organisation/project/repository`, where GitHub
has `owner/repository`:

```
git@ssh.dev.azure.com:v3/archipelacademy/DevelopYourselfPlatform/Campus-FE
                         └ organisation  └ project                └ repo
```

The project segment is dropped, so that repository lands at
`~/Code/archipelacademy/Campus-FE` and every path in the tree has the same
depth. This matches what the old `~/Projects` layout did in effect, since the
repository names there already carry their project (`AuthoringTool-BE`,
`Campus-IaC`).

The cost is that two projects sharing a repository name now collide. Mirroring
the full namespace instead would avoid that and would also handle GitLab
subgroups for free, at 24 characters and one directory level. Worth revisiting
if a collision ever turns up; moving between the two is one `mv` per
repository.

## Git identity

Personal identity is the global default. Work identity is attached to the
owner directory, by hand, one block per organisation:

```gotmpl
[includeIf "gitdir/i:~/Code/archipelacademy/"]
    path = config-work-archipel-academy
```

`gitdir/i:` rather than `gitdir:` because git compares the path as text and is
case-sensitive by default, while both filesystems here are not — the only
symptom of a mismatch would be a work commit quietly attributed to the
personal address.

New organisations are rare enough that generating these blocks from a list of
owners was not worth the template complexity.

### Why not `hasconfig`

Git 2.36 added `includeIf "hasconfig:remote.*.url:"`, which attaches identity
to the *remote URL* rather than the path. Both machines are well past that
version (macOS 2.55, laptop 2.54), so it was a genuine option, and it was
measured rather than guessed. Recorded here so the choice does not have to be
re-derived.

It would have made a work repository correct wherever it sat, including in the
old `~/Projects` tree with no rule at all. It fails in two places instead:

| Situation | `gitdir` | `hasconfig` |
| --- | :-: | :-: |
| Repository in the owner directory | ✓ | ✓ |
| Repository cloned somewhere ad hoc | ✗ | ✓ |
| No remote at all | ✓ personal | ✓ personal |
| `git init`, commit, *then* `remote add` | ✓ | ✗ |
| Personal fork carrying a work `upstream` | ✓ | ✗ |

The last row cannot be fixed. Only the literal `remote.*.url` is supported —
a pattern pinned to `remote.origin.url` matches nothing, silently — so the
condition is really "any remote matches", and a fork with a work remote under
any name inherits the work identity.

`gitdir` won because the whole point of this layout is that a tool puts every
clone in a derived location, which makes the directory a trustworthy signal.
The failure mode `hasconfig` fixes is one that stops occurring once nothing is
cloned by hand.

Two glob findings, kept because they cost an afternoon to discover. The
pattern is gitignore-style wildmatch: `*` cannot cross a `/`, and `**` only
works as a complete path component. So the obvious patterns silently match
nothing:

```
**/*dev.azure.com*/**     matches ssh, https and mixed-case org   ← the working shape
**/archipelacademy/**     matches ssh and https, misses PascalCase org
git@ssh.dev.azure.com:*   matches nothing
*dev.azure.com*           matches nothing
**dev.azure.com**         matches nothing
```

And there is no case-insensitive variant. `hasconfig/i:` does not error — the
entire `includeIf` block is dropped without a word.

## The `repo` command

Not built yet. The layout is designed around it, so its contract is fixed
here:

- **Normalise every URL form to one path.** SSH, HTTPS, Azure DevOps's `v3/`
  and `_git/` segments, userinfo prefixes, a trailing `.git`, and
  `owner/repo` shorthand all resolve to the same directory. Without this the
  same repository can be cloned twice from two URL forms and nothing notices —
  and because identity is path-based, a mis-derived path means a misattributed
  commit rather than merely an odd location.
- **Clone over SSH.** It behaves identically on both machines. The laptop also
  has Credential Manager configured for `dev.azure.com` over HTTPS, which is
  left alone rather than used.
- **Route on a list of owned owners.** `cyrildewit` and `archipelacademy` go
  to `~/Code/<owner>/`; everything else goes to `~/Code/_external/<owner>/`,
  mirrored the same way. A flag would be forgotten once and mint a stray
  owner directory at depth 1, which is what `_external` exists to prevent.
- **Take an optional name.** `repo <url> <name>` overrides the leaf directory.
  No state file records the override — a database that can disagree with the
  filesystem is worse than not knowing.
- **Be idempotent.** If the computed path exists and its `origin` matches,
  print it and exit 0, so that `cd $(repo <url>)` reads as "ensure this is
  here and tell me where". If it exists with a different origin, print both
  and fail without touching anything. Never fetch or pull; a command that
  clones should not mutate a working tree that might be dirty.

Directories are created by hand until this exists.

## Migration

Done by hand, both machines, no grandfathered tree. `~/Projects` on the work
laptop stops existing rather than becoming a permanent exception with its own
`includeIf` rule.

| Was | Is |
| --- | --- |
| `Code/Personal/cyrildewit.nl` | `Code/cyrildewit/cyrildewit.nl` |
| `Code/Personal/eloquent-viewable` | `Code/cyrildewit/eloquent-viewable` |
| `Code/Personal/giftedness-research` | `Code/cyrildewit/giftedness-research` |
| `Code/Personal/work-log` | `Code/cyrildewit/work-log` |
| `Code/Personal/dotnet-grp-exploration` | `Code/cyrildewit/morti` — its origin is `cyrildewit/morti` |
| `Code/Personal/aspire-samples` | `Code/_external/microsoft/aspire-samples` |
| `Code/Personal/dynamic-search-research` | `Code/_sandbox/` — no origin |
| `Code/ArchipelAcademy/edbooking-Release-…` | `Code/_sandbox/`, or delete — not a git repository |

Then the laptop's repositories, out of `~/Projects` and into
`~/Code/archipelacademy/`. Doing that by hand is what catches two Azure
DevOps projects sharing a repository name, which dropping the project segment
turns into a collision.

## Deliberately not done

- **Backup rules for `_external` and `_sandbox`.** A Time Machine exclusion
  would have to stay in sync with a convention that is days old.
- **Generated `includeIf` blocks.** With two owners, the drift they prevent is
  theoretical.
- **A chezmoi script creating the skeleton.** `repo` will do it.
- **A `doctor` check for the invariant.** Nothing depends on it being machine-
  verified yet.
