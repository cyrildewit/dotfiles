---
name: work-log
description: Capture something worth remembering as an issue in the private work-log repo. Drafts the entry from the current session plus git/PR evidence, proposes it for approval, then files it with `gh`. Use when the user wants to log work, record an accomplishment, feedback received, or a learning — or invokes /work-log.
---

You're going to capture a piece of work as a structured issue in the user's private
work-log repo. That issue is a raw capture: the `work-log-curate` skill later merges it
into the repo's markdown log, brag doc, feedback log, and review prep.

Your job is to make the capture **rich and honest** — the session transcript holds detail
the user will not remember in a month. Draft from it rather than asking them to retype it.

## 0. Preconditions

```bash
gh auth status
gh repo view "${WORK_LOG_REPO:-cyrildewit/work-log}" --json nameWithOwner,isPrivate
```

- `WORK_LOG_REPO` overrides the target; default `cyrildewit/work-log`.
- **Refuse to file if `isPrivate` is false.** Work-log entries name employers, colleagues,
  internal services, and story numbers. Say so and stop.
- Never include credentials, tokens, customer PII, or verbatim proprietary source. Describe
  what the code did; don't paste it.

## 1. Gather evidence

Prefer facts over impressions. Draw on, in order:

1. **This session** — what was actually done, decided, found, fixed, or retracted. This is
   the highest-signal source and the reason the skill exists.
2. **Git** — in the current repo, to pin concrete refs:
   ```bash
   git log --author="$(git config user.email)" --since="7 days ago" --oneline
   git branch --show-current
   ```
3. **The forge** — PR/story numbers if reachable (`gh pr list --author @me --state all --limit 10`).
   Azure DevOps work items usually appear as `#NNNNN` in branch names like
   `feature/52691-sync-campus-product`; extract them rather than inventing them.

If the user named the thing to log explicitly, that framing wins — use the session only to
add the supporting detail they left out.

## 2. Classify

Pick exactly one category; it becomes a label:

| Category | Use for |
| --- | --- |
| `shipped` | A feature, endpoint, or change delivered end-to-end |
| `review` | A PR/design review where you added real value |
| `investigation` | Diagnosing a bug, incident, risk, or data gap |
| `collaboration` | Helping a colleague, refinement input, standup/team moves |
| `feedback` | Praise or criticism **received** — always also record who and when |
| `learning` | Something you leveled up on, a deep-dive, a training |
| `tooling` | Tooling/automation built for yourself or the team |

## 3. Draft the issue

**Title:** `<concrete thing, no category prefix> — YYYY-MM-DD`
e.g. `Campus event deletion endpoint in Portal-BE (#53617) — 2026-08-06`

**Body:** exactly this shape. `work-log-curate` parses these headings, so keep them literal.
Omit a section entirely when it has nothing real in it — never leave a placeholder bullet.

```markdown
**Company:** archipel-academy
**Date:** 2026-08-06
**Category:** shipped
**Refs:** story #53617 · `feature/53617-delete-event` · PR 1234

## What I worked on

- <concrete, one line each — what you actually did>

## Impact

- <why it mattered: business/user/team outcome, metrics or magnitudes if any>

## Collaboration

- <who you worked with, cross-team scope>

## Learnings

- <what you learned or leveled up on>

## Feedback

- <praise/criticism received, with source and date>
```

Drafting rules:

- **Write what changed, not what you touched.** "Blocks deletion for enrolments of any
  status, closing a gap the supplier UI still has" beats "worked on delete endpoint".
- **Quantify when you can** — 20 call sites, 425/425 tests, 26 warnings, a 100 s timeout.
- **Keep it honest.** Record retractions and disproven findings; they are evidence of rigor
  and the user values them. Don't inflate a small fix into a milestone.
- **Don't map to learning goals here.** `work-log-curate` owns that, with the whole repo
  tree in front of it.
- Default `Company` to `archipel-academy` unless the user says otherwise.

## 4. Propose for approval

Render the draft as markdown so it reads well in the terminal:

- A `###` heading with the proposed title.
- The category and refs as a bold **Category** / **Refs** line.
- The body inside a fenced ` ```markdown ` block.

Then ask for approval with the interactive question tool — offer *file it*, *edit first*,
and *cancel*. If the user asks for edits, revise and re-propose; do not file until approved.

## 5. File it

```bash
gh issue create \
  --repo "${WORK_LOG_REPO:-cyrildewit/work-log}" \
  --title "<title>" \
  --body-file <tmp file> \
  --label work-log \
  --label "<category>"
```

Write the body to a temp file rather than passing `--body` inline — the content is
multi-line markdown and will not survive shell quoting intact.

If a label is missing, create it rather than dropping it:
`gh label create <name> --repo <repo> --color <hex> --description "<desc>"`.

Leave the issue **open**. Open means "not yet curated"; `work-log-curate` closes it on merge.

## 6. Report

Print the issue URL. If the session contains other loggable work you did not capture,
mention it in one line and offer to file those too — one issue per distinct thing, not one
issue per week.
