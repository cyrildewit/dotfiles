---
name: create-pr
description: Write a pull request title and description from the current branch's diff against its base, then open it as a draft. Follows the repository's PR template when there is one and falls back to a reviewer-oriented default. Use when the user wants to open a pull request, write a PR description, or invokes /create-pr.
---

You're going to write a pull request for the current branch and open it as a draft.

A PR description carries the author's understanding across to the reviewer. The author spent
hours building a model of the problem; the description compresses that model into something a
reviewer absorbs in a minute. Text written without the intent to be read will not be read. If a
description looks generated, reviewers treat it as generated and skip it.

The destination comes from the user's prompt. They may name a forge, a project, or a tool to use.
Take the instruction at face value and use whatever is available in the session. Do not assume a
particular CLI or MCP server exists, and do not parse remote URLs to guess a forge.

## 0. Preconditions

```bash
git fetch --quiet                                   # stale refs produce the wrong diff
git branch --show-current
git status --porcelain                              # uncommitted work
git rev-parse --abbrev-ref @{u} 2>/dev/null         # is there an upstream at all
git log @{u}..HEAD --oneline 2>/dev/null            # commits not on the remote
```

**Stop** if the current branch is the base branch itself. There is nothing to open a PR from.

**Resolve the base branch** in this order, and report which one was chosen:

1. `origin/develop`, when `git rev-parse --verify --quiet origin/develop` succeeds
2. the repository default, from `git symbolic-ref --quiet refs/remotes/origin/HEAD`
3. `main`

A wrong base silently swallows or invents whole commits, so the chosen base always appears in the
proposal for the user to check.

**Uncommitted changes.** Never read them into the diff. They are not on the branch, so they are
not in the PR, and describing them would document code the reviewer cannot see. Warn instead:
`3 files have uncommitted changes and are not covered by this description.` Then carry on.

**Unpushed commits.** Say how many, and offer to push before creating the PR:

```
2 commits are not on the remote. The PR would be missing them. Push first?
```

If the user declines, continue and describe the branch as it stands, noting that the PR will not
match. Never push without asking. A push is the first outward-facing step in this flow and can
trip CI and branch policies.

## 1. Gather the diff

```bash
BASE=<resolved base>

git diff $BASE...HEAD --stat        # shape: files and line counts
git diff $BASE...HEAD              # the full diff
git log $BASE..HEAD --oneline      # the commits
```

Three dots on the diff, deliberately. `$BASE..HEAD` folds in commits made on the base since the
branch diverged and would describe changes that are not the author's.

Read the actual diff. The stat alone is not enough to write a description from.

## 2. Classify by size

Classify from `git diff --stat` before writing a word, then hold to the budget. A three line fix
carrying a five section description is the loudest signal that nobody wrote it.

| Size | Lines changed | Sections allowed |
| --- | --- | --- |
| Small | under 50, one concern | Summary only |
| Medium | 50 to 200 | Summary and at most two more that earn their space |
| Large | over 200, or several concerns | Every section that applies. Reviewer notes are required |

**Budget rule.** For small and medium PRs the body is shorter than the diff. If it is longer,
cut. Cut from the bottom up: Testing first, then How, then Why.

## 3. Find the repository template

```bash
ls .github/pull_request_template.md .github/PULL_REQUEST_TEMPLATE.md \
   PULL_REQUEST_TEMPLATE.md docs/pull_request_template.md \
   .azuredevops/pull_request_template.md 2>/dev/null
ls .github/PULL_REQUEST_TEMPLATE/*.md 2>/dev/null
```

- **One template found.** Follow it. Fill its sections in its order with its headings, then extend
  it loosely so the elements of the default body below are present. The motivation matters most: a
  template with no room for the why gets a section appended rather than losing it.
- **Several found** under `.github/PULL_REQUEST_TEMPLATE/`. Ask which one applies.
- **None found.** Use the default body in step 6.

A team template is a convention other people read. Keep its shape recognisable and add to it
rather than replacing it.

## 4. Establish the motivation

Every PR answers why the change exists, whatever its size. Even a twenty line fix has a reason: a
bug report, an incident, a wrong code path, a prerequisite for later work. Reviewers can check
whether code compiles without it, but not whether it solves the right problem.

Look for the why in the diff, the commit messages, the branch name, and the current session, in
that order. When it is still unclear, ask with `AskUserQuestion`:

- What problem does this solve? What was broken, missing, or slow before it?
- Is this a prerequisite for other work? What does it unblock?
- Was there a specific incident, request, or decision behind it?

A fabricated motivation is worse than an absent one. "Improves code quality" and "cleans up
technical debt" are filler, not reasons. If the user declines to explain, write the summary without
a why and say that the gap is deliberate.

"Addresses review feedback" is also not a why. Each change in a follow-up PR prevents something
concrete. Name what goes wrong without it.

## 5. Draft the title

Active voice, present tense, full scope.

Pattern: `<verb> <what> [in/for/to <context>]`

| Good | Bad |
| --- | --- |
| Add user authentication | Added user authentication |
| Fix memory leak in cache | Fixing memory leak |
| Use Redis for session lookup instead of a DB query | Update session.py |

**Hard cap of two consecutive nouns.** Three or more sends the reader down a garden path.
`Add counters to health-check posts to diagnose slow executor drain`, not
`Add health-check posting observability for executor drain diagnosis`. Read it aloud. If you would
not say it to a colleague, rewrite it.

The title goes in its own field on every forge, so keep it separate from the body throughout.

## 6. Draft the body

Only `## Summary` is required. Every other section has to earn its place through the size gate.

```markdown
## Summary

<Two sentences. First the problem, concrete where possible: an error, a number, a
missing capability. Second what this does about it.>

## Why

<The problem in detail. Show the failure: the error, the wrong output, the gap it
leaves. Omit when the summary already carries it.>

## How

<The design pattern across the change, not a file by file tour. Lead with the idea,
then the specifics. Name alternatives rejected when the choice is not obvious. Omit
unless the change is large.>

## Notes for the reviewer

- **Bolded headline, then the detail.** One bullet per non-obvious fact.
- **Focus area:** where a second opinion is worth most.

## Testing

<What is covered, what is not, how to run it.>
```

Notes on the sections:

- **Summary** is the whole description on a small PR. Two clean sentences. If they will not fit,
  the diff has not been understood well enough yet. Read it again.
- **How** describes the shape of the change, not the steps taken to build it. If it reads like a
  file by file tour, cut it.
- **Notes for the reviewer** is for facts the diff cannot carry: a fallback path, a deliberate
  omission, a place where a second opinion would help.

Where a scope boundary matters, put one sentence in the summary: `Covers the login flow; sign-up
is a follow-up.` It stops reviewers flagging gaps that are deliberate.

Visual aids earn their space when they beat prose. A before and after table for changed observable
behaviour, a small mermaid diagram when data flow changed, terminal output or a screenshot for CLI
and UI changes, `<details>` for benchmarks and long tracebacks. The description has to make sense
without expanding anything.

## 7. Cut

Read it back before proposing.

1. Could a reviewer learn this sentence from the diff alone? Cut it.
2. Does one section repeat another? Cut the weaker one.
3. Is a paragraph longer than four lines? Split or trim it.
4. Is the body over budget for this size class? Keep cutting from the bottom.
5. Read it aloud. Rewrite anything that makes you wince.

The best description is the shortest one that still transfers the understanding.

## 8. Propose for approval

Render the draft as markdown so it reads well in the terminal:

- The base branch, the size class, and the template used, on one line.
- Any precondition warnings, uncommitted files or unpushed commits.
- The title on its own line.
- The body inside a fenced ` ```markdown ` block.

Then ask with `AskUserQuestion`:

- `header`: `PR draft` (max 12 characters)
- `question`: the proposed title
- `preview`: the full body
- Options: `Create the draft` · `Edit first` · `Cancel`

Do not add an "Other" option. The tool supplies a free-text escape hatch of its own. On any answer
other than approval, take the feedback, revise, and propose again. Create nothing until approved.

## 9. Create the draft pull request

Write the body to a temp file first, then pass the file to whichever tool is doing the creating.
Never pass a multi-line body inline. It will not survive shell quoting intact.

Create it as a **draft**, always. The user marks it ready for review.

Use the tooling the user's prompt points at, or whatever the session has available. If nothing can
create a PR and no destination was named, print the body, print the temp file path, and say that
nothing was posted.

## 10. Report

Print the PR URL and note that it is a draft awaiting the user's review.

---

## Prose rules

The `unslop` skill covers the general case and applies here in full. These are the additions that
matter for pull requests specifically, plus the few worth restating because they are the ones that
show up most.

1. **No em dashes.** Use a period or a comma. Not an en dash, not a hyphen standing in for one, and
   not parentheses as a substitute.
2. **No contrastive negation**, in any of its shapes: "not just X, but Y", "it's not A, it's B",
   "this isn't A. It's B", "less X, more Y". State the point directly.
3. **Never open a sentence with** "This PR", "This change", "This commit", or "In this pull
   request". Start with the problem, the action, or the component. "This PR adds retry logic to the
   ingestion pipeline" becomes "Retry logic in the ingestion pipeline now backs off exponentially."
4. **No puffery.** robust, comprehensive, seamless, streamline, leverage, crucial, delve,
   underscore, showcase, landscape as a metaphor.
5. **Padding test.** If the sentence means the same without its adjectives and adverbs, cut them.
   "Bumped dependencies" beats "performed a scheduled dependency refresh as part of ongoing
   maintenance practices".
6. **Diff test.** Could the reviewer learn this from the diff? Then it does not belong in the
   description.
7. **Be specific.** "p50 dropped from 45 ms to 3 ms" earns trust. "Improved performance
   significantly" does not.
8. **No session context.** Never mention plans, phases, task IDs, scratch files, or approaches
   tried and abandoned during the work. The reader has the repository and the diff, nothing else.
   Do not explain code that was never committed, and do not compare the design to an earlier
   attempt nobody saw.
9. **Describe the final state.** Not what the PR leaves out, not what was taken out, unless it was
   committed before. "Not X because Y" still puts X in the reader's head for no reason.
10. **Active voice. Sentence case headings. No emoji.**
11. **Spoken word test.** Would you say this sentence out loud to a colleague? If not, rewrite it
    shorter.

## Important rules

- NEVER mention Claude, AI, agents, or assistants anywhere in the PR.
- NEVER add "Generated with Claude Code" or any similar attribution.
- NEVER add `Co-Authored-By` trailers.
- ALWAYS create the PR as a draft. Never mark it ready for review.
- ALWAYS write the body to a temp file. Never pass it inline.
- NEVER include uncommitted changes in the diff or the description.
- NEVER push without asking first.
- NEVER invent a motivation. Ask, or say that the why is missing.
- Do not detect the forge, parse remote URLs, or extract ticket and work item numbers. If a work
  item belongs on the PR, the user's prompt will say so.
- Do not write a changelog. The description reflects the current state of the branch against its
  base, as if written fresh. No "also adds", no "additionally", no "now includes".
