# cross-review — domain glossary

The vocabulary this toolkit uses. Skills and docs should use these terms
rather than drifting to synonyms.

## Terms

**Controller** — the agent running the review. It states the intent, chooses
axes and lenses, dispatches reviewers, rules on findings, and fixes. It does
not review.

**Reviewer** — a separate agent process, on a different model family than the
controller, invoked read-only with one *lens* on one *axis*.

**Axis** — *what counts as a standard*: Correctness, Spec fidelity, or Coding
standards. An axis can pass or fail independently of the others.

**Lens** — *how the reviewer challenges*: Skeptic, Architect, or Minimalist.
A stance, not a dimension.

**Panel** — the set of reviewers dispatched in one round.

**Round** — one dispatch → collect → rule cycle.

**Baseline** — the commit sha a round's diff is measured from. Pinned without
writing to the working tree or the branch history.

**Delta** — the difference between the previous round's baseline and the
current tree. Rounds after the first review only the delta.

**Finding** — one defect, identified by `file:line`. A finding carries a
severity, but the location is the finding and the severity is an opinion.

**Accepted / rejected / deferred** — the controller's ruling on a finding.

**Adjudicator** — a third reviewer dispatched only when two reviewers reach
opposite conclusions about the same location.

**Transport** — how a reviewer process is started: interactive panes (L3),
print mode (L2), or a same-harness subagent (L1).

**Contract** — the finding format in `review-agent`: P0–P3 severities, the
`No findings.` sentinel, the evidence rules, and the axis/lens header.

## Avoid

- "dimension" for lens — lenses are stances; axes are dimensions.
- "reviewer" for the controller, and "review" for the controller's ruling.
- "score" — there is no scoring; there are rulings.
