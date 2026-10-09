---
name: commit-and-push
description: Commit all changes as conventional micro commits and push, without asking for approval. Only use when the user explicitly invokes /commit-and-push.
disable-model-invocation: true
---

Read `../conventional-commits/SKILL.md` and follow its procedure, with these
overrides:

- **Steps 0–3 and 5**: follow them as written, but skip the proposal template.
  Grouping and commit messages follow the same rules.
- **Step 4**: do not ask for approval. Stage only that group's files and commit
  right away.
- **Step 6**: do not ask. Once every group is committed, push the branch. Use
  `git push -u origin <branch>` when it has no upstream yet.
- Never force push.

Stop and ask the user only when something is ambiguous or risky:

- The changes look like they contain secrets or credentials.
- Unrelated, half-finished work is mixed in and the grouping is unclear.
- A commit hook or the push fails.

When done, print one line per commit (short hash and subject) followed by the
push result.
