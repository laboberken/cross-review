# Axes

An **axis** is what counts as a standard. A **lens** (`lenses.md`) is how a
reviewer challenges. A reviewer is dispatched with one of each: an axis and a
lens form a pair, never a cartesian product.

## The three axes

| Axis | Asks |
|---|---|
| **Correctness** | Does the change do what it claims, without breaking anything? What fails, what is unhandled, what is believed but unproven? |
| **Spec fidelity** | Does the change do what the spec asked — all of it — and nothing it did not ask for? |
| **Coding standards** | Does the change follow this repository's documented standards, and the smell baseline below? |

An axis passes or fails on its own. Spec passing while Standards fails is a
real and reportable result; the two are never averaged.

### Correctness

The default axis, and the only one that needs no external input. It covers
regressions, unhandled states, error paths, concurrency, off-by-one and
boundary errors, and claims the code makes that nothing verifies.

### Spec fidelity

Needs a **spec source**. Finding one is `spec-sources.md`'s job.

A Spec-axis finding must be one of three kinds, and must name which:

- **MISSING** — the spec asks for something the change does not do.
- **PARTIAL** — the change does some of what the spec asks, in a way that
  leaves the requirement unmet.
- **CREEP** — the change does something the spec does not ask for.

Every Spec-axis finding quotes the spec line it checks against. A finding
that cannot quote a line is an opinion about scope, not a finding — send it
back to the Correctness axis instead.

If no spec source exists, the axis does not run. Report
`Spec axis: NOT RUN (no spec source)`. Never report it as passing.

### Coding standards

Sources, in order:

1. The repository's documented standards — `AGENTS.md`, `CLAUDE.md`,
   `CONTRIBUTING.md`, `CODING_STANDARDS.md`, `docs/adr/`.
2. The smell baseline below, which applies even when a repository documents
   nothing.
3. Anything tooling already enforces, which is **skipped** — a linter that
   fails the build has already reported it.

## The smell baseline

Twelve smells from Fowler's *Refactoring*, ch. 3. Each is a labelled
judgement call ("possible Feature Envy"), never a hard violation.

| Smell | What it is | How to fix it |
|---|---|---|
| **Mysterious Name** | A function, variable, or type whose name doesn't reveal what it does or holds. | Rename it. If no honest name comes, the design is murky. |
| **Duplicated Code** | The same logic shape in more than one hunk or file in the change. | Extract the shared shape, call it from both. |
| **Feature Envy** | A method reaching into another object's data more than its own. | Move the method onto the data it envies. |
| **Data Clumps** | The same few fields or params keep travelling together. | Bundle them into one type and pass that. |
| **Primitive Obsession** | A primitive or string standing in for a domain concept. | Give the concept its own small type. |
| **Repeated Switches** | The same `switch`/`if` cascade on the same type recurs. | Polymorphism, or one map both sites share. |
| **Shotgun Surgery** | One logical change forces scattered edits across many files. | Gather what changes together into one module. |
| **Divergent Change** | One file is edited for several unrelated reasons. | Split so each module changes for one reason. |
| **Speculative Generality** | Abstraction, params, or hooks for needs the spec doesn't have. | Delete it; inline until a real need shows. |
| **Message Chains** | Long `a.b().c().d()` navigation. | Hide the walk behind one method on the first object. |
| **Middle Man** | A class or function that mostly just delegates. | Cut it; call the real target. |
| **Refused Bequest** | A subclass ignoring most of what it inherits. | Drop the inheritance, use composition. |

### The two binding rules

1. **The repo overrides the baseline.** A documented standard always wins.
   Where a repo standard endorses something the baseline would flag, suppress
   the smell.
2. **Always a judgement call.** Name the smell and quote the hunk. Never
   report a smell as a standards violation without saying which documented
   rule — if any — it breaks.

## Assigning a pair

Panel size and pair assignment are separate. Size follows risk (see
`SKILL.md` §2); assignment follows whether a spec exists.

With a spec source:

| Reviewer | Lens | Axis |
|---|---|---|
| 1 | Skeptic | Correctness |
| 2 | Spec-Fidelity | Spec |
| 3 | Architect | Standards |

Without a spec source:

| Reviewer | Lens | Axis |
|---|---|---|
| 1 | Skeptic | Correctness |
| 2 | Architect | Standards |
| 3 (large panels only) | Minimalist | Correctness |

Two reviewers is the default for a normal change. A three-reviewer panel adds
the third row; it never multiplies the axes by the lenses.

**Why pairs rather than a product.** Six reviewers would cover every
combination and cost three times as much to discover the same defects. The
measured result behind this toolkit is that different *models* find different
defects; different *combinations of one model's own roles* find far fewer.
Spend the panel on model diversity first, axis coverage second.
