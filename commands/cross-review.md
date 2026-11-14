---
description: Cross-model adversarial code review over herdr-core (default scope: git diff HEAD)
agent: build
---

Use the `cross-review` skill to run a cross-model adversarial review of the
current change.

Arguments: $ARGUMENTS

Rules:

- Parse the remaining natural-language text as the scope. Default scope is
  `git diff HEAD` (staged + unstaged uncommitted changes).
- State the change's intent before dispatching any reviewer, and name what is
  out of scope for it.
- Read `references/agents.md` and pick a reviewer whose model family differs
  from yours. If only a same-family reviewer is available, say so and record
  it in the report rather than silently proceeding.
- Scale the panel to the change: 1 reviewer under 50 lines, 2 under 200 lines
  or 5 files, 3 beyond that. Lenses are Skeptic, Architect, and Minimalist.
- Dispatch each reviewer as its own terminal under `hc`, one pane per reviewer
  in a single Herdr tab. Keep the reviewers visible.
- Wait by terminal address, never by name. If a reviewer does not report
  status, collect its review by waiting for the report message instead.
- Present each lens's report in its own section. Do not merge lenses and do
  not rerank across them.
- Apply your own judgment to each individual finding: accept, reject, or
  defer, with a one-line reason. A review that never rejects anything is
  rubber-stamping, not reviewing.
- Re-derive every number in a finding before acting on it. Reviewers
  fabricate plausible examples, and the author inherits them.
- Fix the findings you accepted, land a new baseline commit, then re-review
  only the delta. Cap the loop at 3 rounds.
- Never close, kill, or remove a reviewer's terminal or tab. The user closes
  them so they can read the transcript.
- If the repository's own rules contradict each other, stop and say so before
  dispatching anyone.
