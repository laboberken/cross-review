# A same-model panel, and the host that could not be measured

Two reviewers, the same model, different hosts. One round produced a usable
review; the other produced nothing at all. Both results are recorded here
because the second one is the more useful finding.

## The setup

A throwaway repository (`cr-fixture-run`) with one commit that correctly
implements `spec.md`, and an uncommitted change that breaks it in two ways:

- the cancellation guard narrows from all four post-warehouse states to
  `shipped` alone;
- `refund_amount` swaps `math.ceil` for `round`.

Baseline pinned with the snapshot mechanism in `SKILL.md` §1. No test suite
exists, which the packets stated explicitly.

Two packets were built from `references/task-packet.md`: `Skeptic@Correctness`
and `Skeptic@Spec`. The Spec packet carried the three-kind taxonomy (MISSING /
PARTIAL / CREEP) and the requirement to quote the spec line.

## Round 1 — two opencode reviewers, zero intervention

Both came up, received their task (`first_message.sent: true`), and reported
without a key being pressed.

| Location | Correctness axis | Spec axis |
|---|---|---|
| `orders.py:7-8` guard covers one of four states | P0 | P0, kind PARTIAL, spec line quoted |
| `orders.py:15` `round()` instead of ceil | P0 | P1, spec line quoted |
| `orders.py:3` `POST_WAREHOUSE_STATES` orphaned | — | P3 |
| `AGENTS.md` "integer cents" vs `spec.md` half-cent | flagged | flagged, with why it matters |

**The Spec axis worked.** Both reviewers quoted `spec.md` line ranges, and the
Spec reviewer labelled each finding with its kind — the discrimination v1
could not make at all.

**Both reviewers caught the premise mismatch.** The packet's intent said the
author was *implementing* the feature; the diff in fact regressed a working
implementation. Each independently said so, in its own words, and framed its
findings accordingly. The `finding-format.md` "check the premise you were given"
clause is what caught it.

**Both also caught the rules contradiction** the controller should have found
in preflight: if amounts are always integer cents, `ceil` and `round` are
indistinguishable, so the refund requirement is only testable if sub-cent
amounts are allowed.

## Round 2 — two codex reviewers, no result

Codex never produced a findings file. Neither pane consumed a single token:
`Context 0% used | 0 in | 0 out`.

Two separate blockers, both on the same host:

1. **Folder trust.** `first_message.sent: false`, reason *"it never reported
   its status, so it may be showing a dialog"*. The screen showed
   `Trust this folder?`. At the time, `references/agents.md` recorded this
   dialog against Claude Code only; this run proved **codex raises it too**,
   at least on Windows, and the registry now records both.
2. **The paste was not submitted.** After trust was granted the task arrived,
   but the second reviewer's screen stayed at `[Pasted Content 6908 chars]`
   with an empty context counter. `agents.md` documents this second-Enter
   behaviour for codex; the controller read the screen for one pane and not
   the other.

Both panes were later killed when their tab was closed, `exit 1`. No report
had arrived, so neither review completed.

## What this round does not show

**It does not support the union argument.** Two reviewers on the same model
converged on the same finding set. Their probes used different values
(`250.4` vs `1.4`) and their prose differed, but the conclusions were
identical. Different hosts did not produce different blind spots.

That is consistent with the toolkit's own claim: it is a different **model**
that buys a different set of assumptions, not a different CLI. A same-model
panel is fine for depth — two independent passes over one requirement is
still worth having — but it must not be reported as a cross-model review.

**It also does not measure codex.** Interrupting the run to press Enter would
have made the comparison incomparable, so it was abandoned rather than
patched. The honest statement is: on this machine, codex as an L3 reviewer
needs at least one human keystroke per pane, and opencode needs none.

## What it does show

- The axis/lens pairing produces distinguishable work. The Spec reviewer's
  output is recognisably not the Correctness reviewer's, even on one model.
- The premise check fires, and fires in a way that changes the whole framing
  of a report.
- A reviewer that cannot be reached is a silent failure unless the controller
  reads the screen after dispatch. One `sent: false` and one unsubmitted
  paste both looked like "review in progress" from `hc ls`.
- Transport friction is not uniform, and the difference is measurable: zero
  interventions for two opencode panes, at least two for two codex panes.
