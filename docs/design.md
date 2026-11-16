# cross-review — design record

Written 2026-11-14, after a design interview. Records why the toolkit is
shaped the way it is. Read `README.md` for what it does and `GLOSSARY.md` for
the vocabulary.

## Current state (v1)

`cross-review` dispatches independent reviewer agents on different model
families as visible panes in one Herdr tab, rules on each finding, and
re-reviews only the delta. `review-agent` supplies the finding contract.

Measured result: on one diff, Claude Code found two defects Codex missed and
Codex found none Claude Code missed. The union is the finding set; the
intersection is not.

Six problems, split across three layers. Keeping the layers separate is the
central insight of v2: a transport cost must not present as a protocol defect.

| Layer | Problem |
|---|---|
| Content | no Spec axis |
| Content | no coding-standards axis |
| Process | commits to pin its baseline |
| Transport | expensive and heavy (GUI, another CLI, trust dialogs) |
| Transport | cannot run unattended |
| Policy | a silent 3-round truncation |

## Goals

1. Cover Spec and Standards as axes without growing the panel.
2. Make the transport a slot: the same protocol at a lower rung, never a
   second skill.
3. Leave the working tree and the branch history untouched.
4. Spend in proportion to risk, not to line count.
5. Stop on convergence, and say so loudly when a cap is hit instead.
6. Depend on no engineering workflow. Matt's `docs/agents/` is one candidate
   among several.

## Decision index

Every implementation decision in the spec, and where it is recorded here.

| Spec decision | Here |
|---|---|
| Skill set topology | D1 |
| Axes and lenses are orthogonal, assigned as pairs | D2, D3 |
| Report shape | D5 |
| Findings: dedup and adjudication | D6, D7 |
| Baseline and artefacts | D8, D9, D10 |
| Spec source discovery | D11 |
| Transport ladder | D12, D13, D14 |
| Cost and scheduling | D15 |
| Stop condition | D16 |
| Contract change | D17 |
| Registry friction | D18 |
| Workflow independence | D19 |

## Decisions

### D1 — Keep two skills; change them in place

`cross-review` stays one skill; `review-agent` stays independently
installable. v2 replaces v1 in place — no parallel branch, no rename.

**Why.** The two answer different questions and are useful apart. A third
skill would duplicate the packet and ruling logic, which is exactly the
failure v2 is removing elsewhere.

**Rejected.** Splitting per transport (`cross-review-herdr`,
`cross-review-ci`): clean boundaries, but the protocol would be copied three
times and drift.

### D2 — Axes and lenses are orthogonal

Axes are *what counts as a standard*: Correctness, Spec fidelity, Coding
standards. Lenses are *how the reviewer challenges*: Skeptic, Architect,
Minimalist. A reviewer receives one `(lens, axis)` pair.

**Why.** The two answer different questions; a reviewer can challenge
correctness skeptically or standards architecturally. Pairing covers both
dimensions without a cartesian product.

**Rejected.** Axis-first with a fixed Skeptic lens: closest to `code-review`,
but loses structural challenge entirely.

**Rejected.** Cartesian product (6 reviewers): correct in principle,
unaffordable.

### D3 — Default pairs depend on whether a spec exists

With a spec: `Skeptic@Correctness`, `Skeptic@Spec`,
`Architect@Standards`. Without: `Skeptic@Correctness`,
`Architect@Standards`, Spec axis `NOT RUN`.

**Why.** Same panel size as v1. Each reviewer gains a dimension rather than
each dimension gaining a reviewer.

**Rejected.** Two-phase (axes first, lenses on the delta): deepest coverage,
but doubles rounds and cost.

### D4 — Standards axis carries the smell baseline, repo overrides

The 12-item Fowler smell baseline, with two binding rules: a documented repo
standard always wins, and every smell is a labelled judgement call, never a
hard violation. Skip what tooling already enforces.

**Why.** A project documenting nothing still gets a standards check, and
`code-review` already proved the baseline works with those two rules.

**Rejected.** Tool output only: objective, but blind to smells.

**Rejected.** Lint config only: lighter, but answers half the problem.

### D5 — Report axis-first, lens-within

`## Correctness` → `### Skeptic`. Each axis reaches its own pass/fail. Within
an axis, lens reports are presented separately and not reranked. Never a
single cross-axis winner.

**Why.** "Spec failed while Standards passed" is one result and must read as
one. Axis is the dimension that can pass or fail; lens is not.

**Rejected.** Flat per-reviewer sections: the reader must reconstruct the axis
conclusion themselves.

### D6 — Deduplicate by `file:line` before ruling

Two axes at one location is corroboration, credited to both.

**Why.** Location is the finding; severity is an opinion. Measured: Claude
P3 and Codex P2 on the same line.

### D7 — Adjudicator only for same-axis contradictions

Dispatch only when two reviewers reach opposite conclusions about the same
location *within the same axis*. Cross-axis disagreement is two results, not
a conflict.

**Why.** Adjudicating a disagreement that was never a disagreement produces
false certainty.

**Rejected.** Adjudicate every contested location: cross-axis "conflicts" are
an artefact of the grouping, not a real dispute.

### D8 — Baseline from a temporary-index snapshot tree

Snapshot the current working tree into a git tree object using a throwaway
index, and use that tree as the baseline:

```sh
snapshot() {
  idx=$(mktemp)
  GIT_INDEX_FILE=$idx git read-tree HEAD
  GIT_INDEX_FILE=$idx git add -A
  GIT_INDEX_FILE=$idx git write-tree
  rm -f "$idx"
}
```

Round 1 is `git diff <base-ref> <snapshot>`. Rounds after the first are
`git diff <previous snapshot> <current snapshot>`. The tree sha, not a commit
sha, is what gets recorded.

**Why.** It captures the working tree — including untracked files — as an
immutable object, without touching the real index, the working tree, or the
branch history.

**Correction (measured).** An earlier version of this decision used
`git stash create -u` and diffed against the resulting commit. That is wrong:
`git stash create` snapshots the tree *as it already is*, so `git diff $sha`
returns empty, and `git diff <commit>` omits untracked files anyway — a
reviewer would have been handed an empty diff. The temp-index form was
verified to show both a modified tracked file and a newly created untracked
file in round 1, and to produce a two-file delta between two snapshots.

**Rejected.** A private ref via `commit-tree` + `update-ref`: works, but writes
a ref for something that needs no name.

**Rejected.** `git stash create -u`: see the correction above.

**Rejected.** Keep the `wip:` commit and soft-reset afterwards: a crash leaves
the noise behind.

### D9 — Findings live inside `.git/`

`<git-dir>/cross-review/round-<N>/<lens>.md`, located by
`git rev-parse --git-dir`.

**Why.** Nothing appears in `git status`, no repo needs a `.gitignore` entry,
and a review leaves nothing behind. Verified that `.review/`-style artefacts
do not contaminate a stash baseline either way, so this is about hygiene, not
correctness.

**Rejected.** Configurable path plus an auto-written exclude line: more
discoverable, one more moving part.

### D10 — No review produces a commit

The `wip: review round N baseline` step is deleted outright.

**Why.** It is the process-layer defect. A tool that commits to inspect
commits has made its own job harder.

### D11 — Spec discovery is layered, with no privileged directory

Six steps, first hit wins: (1) what the user said, (2) what the controller
already has in context, (3) commit-message references, (4) a declaration in
`AGENTS.md`/`CLAUDE.md`, (5) convention scan over `docs/`, `specs/`,
`.scratch/`, `docs/agents/`, `design/`, `rfcs/` as equals, (6) ask once, else
`Spec axis: NOT RUN (no spec source)`.

**Why.** In the common case the review happens inside a flow that just
produced the spec, so steps 1–2 cover it with no configuration. Matt's
`docs/agents/` appears only as one of six equal candidates in step 5, so
switching workflows costs nothing.

**Rejected.** Hard dependency on `docs/agents/`: predicted breakage, and a
skill that only works inside one toolchain is not a toolkit.

**Rejected.** Explicit `--spec` only: predictable, but silently disables the
axis on any day the flag is forgotten.

**Rejected.** A required `review: spec-source` field in every repo: cleanest
mechanically, but asks every repository to write config for a tool it may run
once.

### D12 — Transport is a ladder, declared in the report

- **L3** interactive panes (`$HC_TERMINAL_ID` set, `hc templates` lists
  `reviewer`).
- **L2** print mode (`codex exec`, `opencode run`, `claude -p` — all verified
  present on this machine).
- **L1** same-harness subagent, announced as same-family.

**Why.** The packet, the rulings, and the delta logic are identical at all
three rungs; only the process launch differs. One protocol, three launches,
beats three skills.

**Rejected.** Separate skills per transport — see D1.

### D13 — L2 expresses its verdict as an exit code

`0` clean, `1` findings present but ruling incomplete, `2` accepted blocking
finding.

**Why.** Same reason as "a number no command produced must not appear in a
report": a verdict must be a fact, not prose a caller has to parse.

### D14 — CI is out of scope

No workflow file, no `--ci` flag, no PR-comment publisher.

**Why.** The interactive identity ("the user closes the tab so they can read
the transcript") is worth more than the CI form, and mixing them makes both
worse. The L2 rung stays because it is the cheap *local* path.

**Rejected.** A thin sibling skill plus a workflow example: would be the
honest CI home, and worth revisiting if unattended gating ever matters.

### D15 — Spend by risk, not by line count

Panel size from risk signals: public API touched, money or permissions paths,
a failing test in the change, a user-named area. Line count is a weak
secondary signal. Reviewers are reused across rounds on L3 (`hc send`).
`--quick` runs one reviewer on the cheapest transport.

**Why.** A five-line payment change deserves more scrutiny than a 200-line
comment sweep. Respawn-per-round pays the startup cost every time for no gain.

### D16 — Stop on convergence; keep a cap that speaks

A round accepting nothing ends the review. The cap stays at 3 but prints,
verbatim: `stopped at hard cap 3, round 3 still yielded N accepted findings —
review did not converge`.

**Why.** The old cap was a silent truncation presented as a clean result,
which violates the reporting standard the skill applies to its reviewers.

### D17 — The contract gains a header and one rule

`AXIS: … | LENS: …`, `COVERED: …`, `NOT COVERED: …`, and: Spec-axis findings
quote the spec line they check against. The header is tolerated when absent —
filed under Correctness with a note.

**Why.** Codex ships its own copy of this contract and cannot be updated.
Making the header mandatory would disqualify a whole harness over a formatting
preference. P0–P3 and `No findings.` stay byte-identical so reports remain
comparable.

### D18 — Registry gains a friction column; opencode is the default

Trust dialog, reports status, paste needs a second Enter. Default reviewer on
Windows: opencode. Codex stays available and preferred when its built-in
contract matters more than control.

**Why.** The friction is not uniform across agents — opencode reports status
with no observed dialogs, Codex reports nothing and needs a second Enter.
Choosing by friction buys the most control per unit of babysitting.

### D19 — No workflow coupling anywhere

Nothing in the skill reads or requires a workflow-specific file. `AGENTS.md`
is read for rules and for a possible spec-location declaration; neither must
exist.

**Why.** The daily driver may change. A review tool that breaks when the
planning tool changes is a liability.

## Known limits

- The read-only contract is an instruction plus a scoped allow-list, not a
  sandbox. Check `git status` after every round.
- L2 has no status reporting and no human watching, so a stalled reviewer is
  only visible by timeout.
- Model behaviour is not asserted by any test. Only the protocol's shape and
  the process guarantees are.
- Windows folder-trust dialogs cannot be pre-granted by the skill; they are
  avoided by choosing a reviewer that does not raise them.
- A reviewer that reports a real defect with a wrong worked example can still
  mislead an author who transcribes it. Re-derivation is the only defence.

## Verification

One fixture, three cases, standard library only (this machine has Python
3.15.1 and no pytest), tracked at `tests/fixture/` and run by CI in `fixed`
mode (every case against the corrected module; plain mode is RED on A and B
by design — the planted defects prove the tests detect them). Case C
exercises the shipped `scripts/snapshot-baseline.sh`, so CI tests the
artifact a reviewer runs, not a re-implementation of it:

| Case | Asserts | v1 | v2 |
|---|---|---|---|
| A | cancellation guard, P1 at the guard line | passes | must pass |
| B | unrounded refund → Spec-axis P1 quoting the spec | cannot produce | must produce |
| C | dirty tree + untracked file → no commit, snapshot baseline | fails | must pass |

Case B is the load-bearing one, with a caveat stated plainly: it proves the
defect is real, that a check against the spec is what detects it, and that a
correct implementation closes it. It does **not** prove a panel reports it --
that needs a model to run, and no test here asserts model behaviour. What is
automated is the defect and the process guarantees; the panel's coverage stays
a manual check.

## Measured facts

Verified on this machine while designing, not read from documentation:

- A temporary-index snapshot tree captures both a modified tracked file and a
  newly created untracked file, and produces a correct two-file delta between
  two snapshots, while leaving the real index and working tree untouched.
- `git stash create -u` does **not** work as a baseline: it snapshots the
  already-changed tree, so `git diff $sha` is empty, and `git diff <commit>`
  omits untracked files regardless.
- Python 3.15.1 is present; pytest is not.
- `codex exec`, `opencode run`, and `claude -p` are all present.
- `hc 0.1.21`, with `$HC_TERMINAL_ID` set, so L3 is live in this environment.
