# cross-review v2 regression fixture

Proof that v2 covers a dimension v1 could not, and that a review leaves no
trace. Standard library only — this machine has Python 3.15.1 and no pytest,
which is the premise the skill's test-command preflight exists for.

```sh
sh run-tests.sh          # RED: the defects are planted in orders.py
sh run-tests.sh fixed    # GREEN: same tests against the corrected module
sh run-tests.sh ac       # Case A + C only
sh run-tests.sh b        # Case B only
```

## The three cases

| Case | What it asserts | v1 | v2 |
|---|---|---|---|
| **A** | `cancel_order` refuses every post-warehouse state, not just `shipped` (`orders.py:9`) | passes | must pass |
| **B** | `refund_amount` rounds **up** to the cent, per the spec (`orders.py:15`) | **cannot produce** | must produce |
| **C** | a review lands no commit, leaves `git status` unchanged, and its round-1 diff includes an untracked file | fails | must pass |

## Why Case B is load-bearing

Case B is what a Spec axis buys. The code is wrong in a way that is perfectly
correct-looking in isolation — `round()` is the obvious thing to write — and
nothing in the diff signals it. Only a check against the requirement catches
it, and the requirement lives in `spec.md`, not in the code.

To prove the case is load-bearing rather than incidentally red: delete the
"must round up" sentence from `spec.md` and Case B has nothing left to fail
against. That is the difference between a Spec axis and a Correctness axis
that happens to have read the spec.

## What is not asserted

Model behaviour. No test asserts that a given model finds a given defect —
that would be flaky by construction. The fixture asserts the protocol's shape
(the two defects are detectable, and provably closed by a correct
implementation) and the process guarantees (no commit, no residue, untracked
files visible).

`orders_fixed.py` exists so the tests can be shown to pass on correct code.
A test that only ever fails proves nothing about its own soundness.
