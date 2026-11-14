# Spec sources

The Spec axis needs something to check against. Find it before dispatching, and
if there is nothing to find, say so and skip the axis — never invent a spec and
never report the axis as passing.

Work the ladder top to bottom. **First hit wins**; stop at the first step that
produces a spec.

## 1. What the user said

The invocation itself is the strongest source. They may name a path, quote a
requirement, reference an issue, or describe the intended behaviour in the
scope argument.

Examples that settle it immediately:

- `/cross-review --spec specs/checkout.md`
- `/cross-review HEAD~3..HEAD — refunds must round up to the cent`
- ``/cross-review the auth fix for #412``

If the user's words contain the requirement, that is the spec. Quote them.

## 2. What the controller already has in context

In the common case the review happens at the end of a development flow that
just produced the requirements: a spec was written, tickets were cut, code was
implemented, tests were run. The controller is the same agent that did that
work, so the spec is already in its context.

Use it. Do not go looking on disk for something you are holding.

This step is why the toolkit needs no convention: it works because a review
normally follows the work, in the same session.

## 3. Commit messages

The reviewed range usually names its own issue.

```sh
git log --format='%s%n%b' <base>..HEAD
```

Look for `#123`, `Closes #45`, `Fixes #45`, `!67`, and tracker keys like
`PROJ-123`. Fetch the issue body when the tracker is reachable.

## 4. What the repository declares

`AGENTS.md` or `CLAUDE.md` may say where specifications live. A line to that
effect settles it, and it is the repository telling you rather than you
guessing.

## 5. Convention scan

Look, in the working tree, at these directories — **as equals**:

```
docs/  specs/  .scratch/  design/  rfcs/  docs/agents/
```

Rank candidates by resemblance to the branch name, the changed paths, and the
commit subjects. A directory holding a `spec.md`, `*.spec.md`, `README.md`, or
a directory named after the branch is a strong hit.

`docs/agents/` and `.scratch/` are on this list because the Matt Pocock skill
set uses them. They get **no precedence** — a repository using `rfcs/` and a
repository using `docs/agents/` are treated identically. The list is a set of
conventions, not a dependency.

## 6. Ask, then skip

If steps 1–5 produced nothing, ask the user once:

> I could not find a spec for this change. Pass a path, or tell me the
> requirement, or say there is none.

If there is none:

```
Spec axis: NOT RUN (no spec source)
```

and carry on with Correctness and Standards. The report names the skip at the
top, in the axis table, so a missing Spec axis is never mistaken for a passing
one.

## What counts as a spec

Any artefact that states intended behaviour in a checkable way: an issue body,
a spec document, a ticket's acceptance criteria, a design note, a written
requirement in the user's own message.

What does **not** count: a branch name, a commit subject on its own, a diff
(that is the change, not the requirement), or your own inference about what
the change was probably meant to do. The last is the dangerous one — it
produces a Spec axis that always passes.
