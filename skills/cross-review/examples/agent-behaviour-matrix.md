# Measured agent behaviour

Every row here was observed on a real run. The protocol is agent-agnostic; the
launch line and the three behaviours below are not.

| Agent | Command | Reports status | Submits its own paste | Startup dialog |
|---|---|---|---|---|
| Claude Code | `claude.cmd` | yes (`claude-code`) | yes | folder trust — `hc keys <t> down` then `enter` |
| Codex | `codex --no-daemon -s workspace-write -a never` | **no** | **no** — needs a second `enter` | "Folder access" panel — `hc keys <t> enter` |
| opencode | `opencode.cmd` | yes (`opencode`) | yes | none observed |

## Status reporting changes how you wait

Claude Code and opencode report an OSC 7501 status, so `hc wait <address>`
returns the moment a turn ends. Codex reports nothing — `hc get` shows
`status: null` and `turn` stuck at `1` while it is working. `hc wait` then
looks for the process to exit, and an interactive TUI stays alive at its
prompt after finishing, so the wait only ever times out.

For an agent that does not report status, **collect the review by waiting for
the report message**, not by waiting on the terminal.

## Paste submission is per agent

`hc send` pastes and presses Enter. Claude Code treats that as a complete
submission. Codex treats it as a paste and leaves it pending:

```text
[Pasted Content 3293 chars]
```

The task is sitting in the input box, unsubmitted, and the reviewer looks
idle. Send `hc keys <t> enter` once to submit it.

The rule that generalises: after any `hc send` to a reviewer, look at the
screen and press Enter if a pasted block is still pending.

## Startup dialogs

**Claude Code** shows a folder-trust dialog on a directory it has not seen.
The selected option is "No, exit", so it takes `down` then `enter`:

```sh
hc read <terminal>
hc keys <terminal> down
hc keys <terminal> enter
```

**Codex** shows a "Folder access" panel naming the repository root, with
`1. Trust and continue` already selected. `enter` alone is enough.

Both grants are saved, so the next launch delivers the task normally. In both
cases `hc run` reported `first_message.sent: false` with the reason "it never
reported its status, so it may be showing a dialog".

## Codex specifics

- `--no-daemon` is required, or its commands run outside Core and the
  reviewer stops being a child of the controller.
- `-s workspace-write` is required: a read-only sandbox blocks the findings
  write.
- `-a never` is required: otherwise it stalls on an approval dialog when it
  runs the delivery command.

## What Codex did with the shared skills

Given the same task, Codex loaded the shared `review-agent` skill for the
finding format and the shared `herdr-core` skill for the handoff, unprompted:

> _As measured, before v3. The contract now lives in
> `skills/cross-review/references/finding-format.md`; the text below is
> left as recorded._

> I'm using the review-agent skill for the defect-first review and herdr-core
> for the required final handoff.

It also honoured the read-only contract:

> I did not inspect any review artifact contents.

and still caught an out-of-scope artifact in the diff from `git diff` alone.
