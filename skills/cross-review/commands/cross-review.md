---
description: Cross-model adversarial code review (default scope: git diff HEAD)
agent: build
---

Use the `cross-review` skill to run a cross-model adversarial review of the
current change. Follow `SKILL.md` in full — this command only parses the
arguments.

Arguments: $ARGUMENTS

- Parse the remaining natural-language text as the scope. Default scope is
  `git diff HEAD` (staged + unstaged uncommitted changes).
- `--quick` runs one `Skeptic@Correctness` reviewer on the cheapest available
  transport.
- Everything else — intent, baseline, transport, pairing, dispatch, ruling,
  re-review, cap — is the skill's protocol, and `SKILL.md` owns it. Do not
  restate it here.
