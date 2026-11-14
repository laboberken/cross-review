# Two reviewers, two model families, one diff

The panel is the point. Two reviewers from different model families saw the
same diff through the same lens with the same packet, and each found defects
the other missed entirely.

## Setup

A small Python module with a working-tree change: a money-rule edit in
`AGENTS.md`, a new `cancel_order`, a new `refund_amount`, and a rounding
change in `price_with_tax`.

```sh
# one tab, one pane per reviewer
herdr-app do tab.new --name "review: 59a610c (2 models)" --folder "$REPO"
herdr-app do pane.close --pane <root-pane-id>

hc run --bg --json --label "herdr.space=$SPACE" --label "herdr.tab=$TAB" \
  --name rev-claude --cwd "$REPO" reviewer       "$PACKET_CLAUDE"
hc run --bg --json --label "herdr.space=$SPACE" --label "herdr.tab=$TAB" \
  --name rev-codex  --cwd "$REPO" reviewer-codex "$PACKET_CODEX"
```

Both packets were identical except for the findings path and the label in the
delivery line. Each reviewer was told not to read any other file under
`.review/`, so neither could see the other's report.

## The result

| Location | Claude Code (Anthropic) | Codex (OpenAI) | Verdict |
|---|---|---|---|
| `orders.py:36` — cancellation guard blocks only the exact status `"shipped"` | P1 | P1 | agreed, same line |
| `orders.py:43` — refundable amount can go negative | P3 | P2 | agreed, **severity differs** |
| `orders.py:31,34,41` — new public functions ship without tests | P2 | P2 | agreed |
| `orders.py:31` — half-cent rounding is inconsistent on binary floats | P2 | — | **Codex missed it** |
| `AGENTS.md:3` — the reconciled money rule contradicts the price helpers that exist | P2 | — | **Codex missed it** |
| the diff also deletes `.review/round1.md`, unrelated to the stated intent | P2 | P2 | both caught it |

## What this changes

**The union is the finding set, not the intersection.** Claude Code found two
defects Codex missed; Codex found nothing Claude Code missed. A single-panel
review would have silently adopted one model's blind spot as truth. That is
the whole argument for running more than one model.

**Location is the finding; severity is an opinion.** The negative-refund
defect is P3 in one report and P2 in the other, at the same line. Aggregate on
`file:line`, and treat the priority label as the reviewer's judgement about
it.

**Both reviewers audited the premise, not just the code.** Each independently
reported the stray `.review/round1.md` deletion as outside the stated intent.
Neither was asked to check the scope — the packet told them to check the
premise, and they did.

**They disagreed on a question of fact.** Codex concluded that the money-rule
edit "resolves the prior wording contradiction"; Claude Code said the rule was
still contradictory. Checking the code by hand confirmed Claude Code: a
two-decimal float at the boundary and integer cents at the boundary cannot
both be the rule. A single-panel review would have accepted the wrong answer.
This disagreement is exactly what the adjudicator axis is for — a third
reviewer given only the contested location, both reports, and the code.

## Output format

Both reviewers produced the same shape, without being told to coordinate:
Claude Code through the shared `review-agent` skill, Codex through its own
built-in one. That is the point of a shared finding format — it makes two
vendors machine-comparable.

> _As measured, before v3. The contract now lives in
> `skills/cross-review/references/finding-format.md`; the text below is
> left as recorded._

```text
[P1] Imperative finding title - path/to/file.py:line
```

Priorities are P0 (release blocker) through P3 (low impact). The sentinel for
a clean review is exactly `No findings.`
