# Troubleshooting

Every entry here was measured on a real run, not inferred.

## The reviewer reviewed the wrong change

**Symptom.** The reviewer spends minutes on findings that belong to an earlier
round. Its transcript shows it reading files under `<git-dir>/cross-review/`
that were not in its scope.

**Measured.** A reviewer was given the working-tree diff and a fresh findings
path. It ran `cat round3.md`, then spent four minutes and 23k tokens
re-verifying the previous round's `order_total` discount defect, and never
wrote its own findings file.

**Cause.** The findings directory was flat and had accumulated every previous
round's reports. The reviewer listed it, read a sibling file, and treated it
as input.

**Fix.**

- One directory per round: `<git-dir>/cross-review/round-<N>/<lens>.md`.
- In the packet: *"Do not read any other file under `<ROUNDS_DIR>/` — files
  there belong to other rounds or other reviewers and are not part of your
  input."*
- Name the one previous file the reviewer may read, explicitly.

**Rule of thumb.** If a reviewer takes more than a few minutes and has not
written anything, check what it has been reading before it finishes.

## The task never arrived

**Symptom.** `hc run` returns `first_message.sent: false`, reason *"it never
reported its status, so it may be showing a dialog"*.

**Cause.** A startup dialog on a directory the agent has not seen — folder
trust, measured on Claude Code and Codex. The reviewer sits on the dialog;
nothing was sent.

**Fix.** Read the screen to confirm it is the dialog, then clear it the way
`references/agents.md` records for that agent — the panel and the keys that
clear it differ per agent.

The grant persists, so re-dispatch and the task goes through:

```sh
hc kill <terminal>; hc rm <terminal>
hc run --bg --json ... reviewer "<PACKET>"     # sent must be true
```

## The wait returned early for an unrelated reason

**Symptom.** `hc wait` returns `reason: "message"` and you expect a report,
but nothing relevant arrives.

**Measured.** `hc wait rev-correctness --timeout 300` returned immediately
with `from: t1m` — a terminal from a *previous* round that had already been
killed. The name resolved to the dead terminal; the wait returned because of
that terminal's queued exit notification.

**Cause.** `hc wait` resolves a **name** to any terminal that carries it,
including finished ones from earlier rounds. And any queued notification for
the parent wakes the wait.

**Fix.** Wait by **address**, never by name. Read the `from` field of the wait
result and confirm it is the terminal you dispatched. If it is not, wait again.

```sh
hc wait t1v --timeout 300
```

## The reviewer was interrupted

**Symptom.** The reviewer's screen ends with `Interrupted`.

**Cause not isolated.** What was ruled out: `hc wait --timeout` does **not**
interrupt a working agent — measured, a probe agent survived two 20-second
timeouts and completed normally (`state: done`, no interrupt).

What remains plausible: a history read against a full-screen TUI. `hc read`
may scroll the app and restore its view, and that can land as stray input in
the agent's own session.

**Fix.**

- Do not `hc read` a reviewer that is still working. Wait for it to finish
  first.
- If you must look, prefer `hc get <address>` (state only) over
  `hc read`.
- When a review is interrupted, check whether the findings file was written
  before it died. If it was, the review completed and the kill is the user's
  tab being closed.

## The report contains a number no command produced

**Symptom.** A finding says "verified" and then shows a value that is
arithmetically wrong.

**Measured.** Round 1 ran the code and observed the right value, then wrote a
different, fabricated worked example into its report. The author copied that
example into a test, and round 2 caught it only by running the suite.

**Fix.** Two layers.

- In the packet: *"A number you did not observe in a command's output must
  not appear in your report."*
- In the controller: re-derive any number in a finding before acting on it.

## The author inherits the reviewer's mistake

Same measurement. The defect was real; the worked example was wrong; the fix
copied the example; only a second independent round caught it.

**Fix.** Never fix a finding by transcribing it. Re-derive the case yourself
and write the test from the derived value. Then let the next round check.

## The reviewer reported, then the tab was closed

**Symptom.** `<hc>t1k rev-correctness exited (exit 1). Read: hc read t1k</hc>`

**Cause.** Closing a tab in the Herdr app kills its terminals. `hc get <t>`
then shows `reason: "killed"`, `exit_code: 1`, `state: "finished"`. Every
terminal of a closed tab dies within a few hundred milliseconds of each other
— the machine's own history shows the same signature on every previously closed
tab.

**This is not a failure.** If a report already arrived, the review completed.
The findings file and the `<hc from=...>` message survive; the tab closure only
takes the live TUI and its scrollback. `hc read <t>` still returns the full
transcript of a killed reviewer, so a post-mortem is possible.

**Distinguish the two cases.**

| Report arrived? | Meaning |
|---|---|
| yes | review completed; the kill is the user's tab being closed |
| no | the reviewer was killed mid-flight — re-dispatch it |

**Do not** close reviewer's tabs yourself. The user closes them so they can
read the process.

## The report arrived but you did not see it in the transcript

**Symptom.** `hc wait` returned `reason: "message"` but nothing appeared.

**Cause.** The report arrives as **your next input**, tagged
`<hc from="tN rev-lens">`. It may land a moment later, and it is not output to
fetch with `hc read`.

**Fix.** Wait for it. Do not `hc read` the reviewer to fetch the report.

## The tab name is rejected

**Symptom.** `bad name "paneA": use 1-32 of a-z 0-9 - _ . starting with a
letter or digit, not shaped like an id (t7)`.

**Cause.** Uppercase letters, or a name that looks like a terminal id.

**Fix.** Lowercase and dash-separated: `pane-a`, `rev-correctness`.

## The `hc run` name and the pane do not match

`--name` is the hc-side handle. `herdr.tab` decides which pane in the tab the
terminal lands in. A terminal with `herdr.tab` but no `herdr.space` may not
appear in the window at all; set both.

## The root pane of the review tab stays empty

`herdr-app do tab.new` always creates the tab with one root terminal. It is a
plain shell, not a reviewer.

**Fix.** Close it:

```sh
herdr-app do pane.close --pane <root-pane-id>
```

Find the pane id from the `terminal` that `tab.new` returned:

```sh
herdr-app ls 2>&1 | Select-String -Pattern '"terminal": "t1r"' -Context 0,2
```

Verified: closing the root pane does **not** disturb the sibling reviewers.

## JSON output will not parse

**Symptom.** `ConvertFrom-Json` on `hc ls` or `herdr-app ls` fails with
*"an unexpected character was encountered: a"*.

**Cause.** Terminal and tab labels carry non-ASCII characters (Chinese names,
emoji) that the Windows JSON parser chokes on.

**Fix.** Do not parse the whole document. Extract with a targeted match:

```powershell
herdr-app ls 2>&1 | Select-String -Pattern '"name": "' -SimpleMatch
```

Or read the raw text and pull only the segment you need.

## The reviewer modified the source

**Symptom.** `git status` shows source files changed by the reviewer.

**Cause.** The read-only rule in the reviewer template is an instruction, not
a sandbox. `--allowedTools` with a broad `Write` permits it.

**Fix.** Check `git status` after every round and treat any source change as a
contract breach. The shipped template scopes `Write` to the findings directory;
if that scope ever fails to hold, narrow the allow-list further.

## The reviewer ran the tests and left `__pycache__`

Expected. Reviewers execute code to verify findings.

**Fix.** `.gitignore` should cover it. Otherwise the reviewer's own artefacts
show up in the next round's diff.

## The review left a commit behind

**Symptom.** `git log` gained a baseline commit named after the review round.

**Cause.** An older version of this skill pinned its baseline by committing.
That is gone: the baseline is a tree snapshotted through a throwaway index.

**Fix.** A review produces no commit on the current branch. If you find one,
the skill is running an old copy — reinstall it.

## The reviewer got an empty diff

**Symptom.** The reviewer reports `No findings.`, or says the scope looks
empty, on a tree that clearly has changes.

**Cause.** The baseline was pinned with `git stash create -u` and diffed as
`git diff $sha`. Measured: `stash create` snapshots the tree as it already is,
so the diff is empty. `git diff <commit>` also drops untracked files, so a
working-tree review misses new files even when the diff is not empty.

**Fix.** Snapshot through a throwaway index and diff two trees — the skill
ships the mechanism as `scripts/snapshot-baseline.sh` (SKILL.md §1). Verify
the round-1 diff with `--stat` before dispatching.

## The reviewer claims a finding is "pre-existing"

**Symptom.** A finding is dismissed because it predates the change.

**Check.** Whether the rule it violates is also new in the same diff. If the
diff adds the rule and violates it in the same change, it is introduced by the
change and is in scope.

## Neither reviewer caught a contradiction in the rules themselves

**Measured.** Two independent reviewers both quoted an `AGENTS.md` rule that
contradicted another rule in the same file. Neither noticed.

**Fix.** The controller checks rule consistency before dispatching. This
belongs to the controller precisely because the reviewers read the rules the
same way the rules are broken.
