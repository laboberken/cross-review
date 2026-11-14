# Incremental re-review: three rounds, and the round that mattered

The fix inherits the reviewer's mistakes. This is the measured chain that
proves it, and the reason the second round exists.

## The setup

Two defects were planted in a `src/orders.py`:

1. a free-shipping threshold changed from `>` to `>=`, contradicting a rule
   in `AGENTS.md` that says the threshold is exclusive;
2. a new `discount` parameter on `order_total` that is accepted and
   documented but never applied.

The existing tests did not cover either one.

## Round 1

The reviewer found both. It also reported a worked example that was
**arithmetically wrong**:

> `order_total([(10.0, 2), (2.5, 4)], discount=5.0)` returns `20.0` instead of
> `15.0`

The true values are `30.0` and `25.0` — the line sums to `10.0*2 + 2.5*4`,
which is 30, not 20. The reviewer had *run* the code and observed the correct
value earlier in its own transcript; the report substituted a plausible
example it had not observed.

Both findings were real. Only the evidence was fake.

## The fix

The author applied the fix and wrote the test the reviewer asked for. The
reviewer's example was copied straight into the assertion:

```python
def test_total_applies_discount():
    assert order_total([(10.0, 2), (2.5, 4)], discount=5.0) == 15.0
```

That test can never pass. It also hid the pre-existing broken assertion
`test_total_sums_lines`, which expects `20.0` for lines that total `30.0`.

## Round 2

The second round was scoped to the delta only, and was told to run the tests
and paste what they printed. It reported:

```text
PASS test_exact_threshold_is_not_free
PASS test_single_item_never_free
PASS test_three_items_over_fifty
FAIL test_total_applies_discount
PASS test_total_never_goes_negative
FAIL test_total_sums_lines

2 FAILED
```

and then found the root cause rather than the symptom:

> The assertion expects `15.0`, which is `20.0 - 5.0` — it inherits the
> incorrect `20.0` subtotal from the pre-existing `test_total_sums_lines`,
> which is itself wrong (it expects 20.0 for lines that total 30.0; I
> confirmed the same 30.0 result from HEAD's `order_total` executed in
> memory, so that expectation was already wrong before this round).

It also flagged a false-confidence trap:

> Note that `test_total_never_goes_negative` passing is not evidence the
> discount path is sound — it expects `0.0`, which the `max(..., 0.0)` clamp
> returns regardless of the arithmetic.

And it checked the premise it had been given:

> HEAD is actually the state round 1 reviewed, not round 2 — its commit
> message is `wip: state reviewed in round 1` … the "working-tree diff
> contains ONLY round-3 fixes" premise does not hold as stated.

## Round 3

After the corrections, the delta was reviewed once more. Verdict: clean, no
new findings, every previous finding marked FIXED with evidence.

## What this changes

**Re-derive every number before acting on it.** The author did not verify the
reviewer's example; it copied it. The defect was correctly identified, the
example was wrong, and the error travelled into the code, into the test, and
almost into the merge.

**A reviewer that cannot run tests cannot verify anything.** Round 1's
reviewer tried `python -m pytest` in an environment without pytest, and fell
back to reasoning. Putting the real test command in `AGENTS.md` is what made
round 2 able to catch the error.

**A passing suite is not evidence.** The suite printed `ALL PASS` while
exercising none of the changed code. A reviewer that only reads a diff cannot
see that.

**Premises get audited, sometimes.** Round 2 caught that the scope it had
been given was wrong. Round 1 and the two-model panel did not. Ask for it
every round; do not assume it happens.
