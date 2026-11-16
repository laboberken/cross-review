# Task packet

The text handed to a reviewer as the argument of `hc run ... reviewer "<PACKET>"`.

Everything must be **already expanded** — the reviewer runs inside a terminal
where your shell variables do not exist. `$HC_TERMINAL_ID`, `$REPO`, the
baseline sha, the round number and the findings path are substituted by you
before dispatch.

## The five ingredients

A reviewer prompt is, in order:

1. the **stated intent**
2. the **lens** and the **axis** (full text from `lenses.md` and `axes.md`,
   not a summary)
3. the **scope** — the exact diff command and the baseline sha
4. the **project rules** — the repository's own `AGENTS.md` and its test
   command
5. the **delivery clause** — where to write the findings, and how to report back

Never rewrite the lens or the brief. The delivery clause is the only thing you
add.

The axis names what counts as a standard; the lens names how the reviewer
challenges. A reviewer is dispatched with a pair, e.g. `Skeptic@Correctness`.
It reports both back in the header `finding-format.md` defines.

## The finding format has one owner

`references/finding-format.md` owns the finding format: the flagging bar,
the header, the entry format, the `P0`–`P3` definitions, and the
`No findings.` sentinel. The packet does not redefine it. At assembly time,
paste that file's contract section — **from `## Flag a finding only when
all of these are true` to the end of the file** — into the packet
**verbatim**. The owner keeps its controller notes above that section, so
the range contains reviewer-facing text only and the two rules do not
collide.

## Round 1 — first review

```text
You are reviewing a change in this repository.

THE INTENT
<what the author is trying to achieve, what success looks like, what is
explicitly out of scope>

YOUR LENS: <LENS NAME>
<full lens text: its challenges, its questions>

YOUR AXIS: <AXIS NAME>
<full axis text: what counts as a standard here, and the questions it asks>

SCOPE
The base is commit <BASELINE_SHA>. The change under review is exactly:
    git diff <BASELINE_SHA>
Review only what that command shows. If what you are about to review is not
what that command shows, say so in your report instead of reviewing something
else.

PROJECT RULES
Read AGENTS.md (or CLAUDE.md) in the repository first and treat it as the
project's standing rules.
Run the project's tests with <TEST_COMMAND> and use the real output as
evidence. A number you did not observe in a command's output must not appear
in your report.
A failing test is a finding.

HOW TO REVIEW
1. Inspect the complete diff, plus enough surrounding code to understand each
   changed path.
2. Find real problems. Be specific — cite files, lines, and concrete failure
   scenarios.
3. Report only actionable findings introduced by this change.
4. Check the premise you were given: if the scope or the intent does not match
   the repository's actual state, say so instead of reviewing anyway.
5. Also look for contradictions between the project's own rules, and report one
   if you find it — the reviewers around you will not spot it.

FINDINGS
Write them to <FINDINGS_PATH>. That is the only file you may write.
Do not read any other file under <ROUNDS_DIR>/ — files there belong to other
rounds or other reviewers and are not part of your input.

<REPORT FORMAT — paste verbatim from references/finding-format.md, from
`## Flag a finding only when all of these are true` to the end: the
flagging bar, the header lines, the finding-entry format, the P0–P3
definitions, and the `No findings.` sentinel. Copy, do not paraphrase: the
contract has one owner, and the packet must stand alone.>

DELIVERY
Write the findings file FIRST. Only then report back with exactly this
command (it is already expanded, run it as-is):

hc send <PARENT_ADDRESS> "<AXIS>-<LENS> DONE: <n> finding(s). Findings: <FINDINGS_PATH>"

The file must be on disk before you send that command: if your terminal is
closed mid-review, the file is the only thing that survives.
Then stop.
```

## Round 2+ — incremental re-review

Only the **delta** since the previous baseline is in scope, plus the previous
round's single findings file so the reviewer can mark each one.

```text
You are reviewing a change in this repository.

THE INTENT
<same intent as round 1, plus what changed since>

YOUR LENS: <LENS NAME>
<full lens text>

YOUR AXIS: <AXIS NAME>
<full axis text>

SCOPE
This is round <N>. The base is commit <BASELINE_SHA>, which is the exact state
round <N-1> reviewed. The change under review is exactly:
    git diff <BASELINE_SHA>
Review only what that command shows.

PROJECT RULES
<same as round 1>

HOW TO REVIEW
1. Read the previous round's findings file: <PREVIOUS_FINDINGS_PATH>
   It is the only file under <ROUNDS_DIR>/ you may read.
2. Read the current `git diff <BASELINE_SHA>`.
3. For each finding in that file, state whether it is now correctly fixed,
   still present, or only partially fixed. Give the evidence: the changed code
   and the actual result of running the tests.
4. Run the tests with <TEST_COMMAND> and report what they print. A failing
   test is a finding.
5. Report only NEW actionable defects introduced by these changes. Do not
   re-list an earlier finding as new; if it is not fixed, list it under
   "Unresolved from round <N-1>".

FINDINGS
Write them to <FINDINGS_PATH>. That is the only file you may write.
Do not read any other file under <ROUNDS_DIR>/.

Keep the header at the top of the file, exactly as the report format you
were given defines it.

Format:

## Round <N-1> findings
- [<SEVERITY>] <title> - FIXED / NOT FIXED / PARTIAL - <evidence>

## New findings
<REPORT FORMAT — the same verbatim block from references/finding-format.md
as round 1.>

If there are no new findings, place the sentinel the report format defines —
exactly "No findings." — under New findings.

DELIVERY
Write the findings file FIRST. Only then report back with exactly this
command (it is already expanded, run it as-is):

hc send <PARENT_ADDRESS> "<AXIS>-<LENS> DONE round <N>: <n> new finding(s), <m> of <k> round-<N-1> findings fixed. Findings: <FINDINGS_PATH>"

Then stop.
```

## The adjudicator

Given only the contested location, both reports, and the code. It decides; it
does not extend the review.

```text
You are adjudicating a disagreement between two reviewers.

CONTESTED LOCATION: <FILE:LINE>
Report A (<LENS A>): <TEXT>
Report B (<LENS B>): <TEXT>

Read the code at that location and the surrounding context. Decide which report
is correct, or that neither is. State the decision and the evidence from the
code that supports it. Report nothing outside the contested location.

FINDINGS
Write your decision to <FINDINGS_PATH>. That is the only file you may write.

DELIVERY
hc send <PARENT_ADDRESS> "ADJUDICATION DONE: <decision for each contested location>. Findings: <FINDINGS_PATH>"

Then stop.
```

## Checklist before dispatching

- [ ] the intent is written, and names what is out of scope
- [ ] the lens text is pasted in full, and the axis text with it
- [ ] the report-format block was pasted from `finding-format.md` verbatim
- [ ] baseline sha exists and resolves
- [ ] the findings path is `<ROUNDS_DIR>/round-<N>/<axis>-<lens>.md`, and
      that directory holds nothing from an earlier round
- [ ] the delivery command's tag is `<AXIS>-<LENS>`, so two Skeptics in
      one panel cannot deliver under the same label
- [ ] the previous round's single file is named explicitly, and the packet says
      it is the only file under `<ROUNDS_DIR>/` the reviewer may read
- [ ] the test command was verified to run, not just read
- [ ] the parent address is expanded
- [ ] the `hc send` command is spelled exactly as shown
