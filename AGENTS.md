## Comments and documentation

- Comment to explain *why*, never to restate *what* the code already says.
- Write a docblock only when the name and signature do not already say it. Skip
  trivial wrappers and `main`.
- Never add a docblock to a function that does not have one just because you
  touched it.
- Keep docblock text professional and isolated from any conversation you and I
  have had. Document the code, not our session.
- Never document decisions, omissions, alternatives considered, or open
  questions. Those belong in the commit message or in `docs/`.
- Never write for a diff reviewer. No "fixed", no "updated to", no "now
  handles". A comment must still make sense read fresh, months later.
- When a comment carries a real gotcha, keep it and cut it to the fewest words.
