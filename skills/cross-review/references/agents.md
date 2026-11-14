# Agent registry

How to start each coding agent as a reviewer under `hc`.

The **protocol is agent-agnostic**: the packet is text, the delivery clause is
text, and the finding format is text. Only the four things below vary per
agent, and they all live here.

| Field | Meaning |
|---|---|
| `command` | how to start it interactively (L3), including Windows specifics |
| `print` | how to run it as a one-shot reviewer (L2), when it has one |
| `prompt` | how it takes the task — `argv` or `stdin` |
| `status` | whether it reports agent status (OSC 7501), and whether that is verified |
| `dialogs` | startup dialogs that block the first message, and how to clear them |
| `friction` | how much babysitting it costs at L3 — see the ladder below |

## Prefer the lowest-friction agent

Friction is not uniform, so the default reviewer is chosen by it rather than
by brand. **opencode is the default on Windows**: it reports status and raises
no startup dialogs observed. Codex is the fallback when its built-in copy of
the review contract matters more than control — it reports no status and its
paste needs a second Enter, so it cannot be waited on by name.

| Agent | Friction | Why |
|---|---|---|
| opencode | **low** | reports status, no dialogs, `argv` prompt |
| claude | **medium** | reports status, but a folder-trust dialog blocks the first message on an unseen directory |
| codex | **high** | no status, paste needs a second Enter, so collect by message not by wait |
| others | unknown | try, then record what you measured |

Pick the lowest-friction agent **whose model family differs from yours**. The
cross-model requirement outranks the friction preference: a low-friction
same-model reviewer is not a review.

## The contract every reviewer must satisfy at L3

1. Runs as an **interactive TUI**, not a one-shot print mode. A one-shot mode
   (`claude -p`, `codex exec`) never reports status and cannot be watched or
   steered.
2. Takes the task **as a prompt argument**, so the first message is delivered
   with the launch.
3. Has a **shell tool**, so it can run `hc send <parent> "<result>"`.
4. **Respects its working directory**, so relative paths in the packet resolve
   against the reviewed repository.

An agent that does not report status still works: `hc wait <t>` then waits for
the process to exit instead of for a status change, and `hc read <t>` still
returns the output. Status reporting only makes the wait nicer.

At **L2** the contract is looser: a print-mode run needs no status, no shell,
and no stdout discipline beyond writing its findings file. It cannot report
back, so the controller reads the findings file after the process exits.

## Registered agents

### claude (Claude Code)

- **command**: `claude.cmd` — the Windows npm shim. The npm bin directory also
  contains a bash shim named `claude`, which is what resolves when the command
  runs through `sh` (as templates do). Both work.
- **print**: `claude -p "<PACKET>"` with `--allowedTools` scoped as below. Use
  at L2 only. Do **not** use it at L3 — it never reports status.
- **prompt**: `argv`. Verified.
- **status**: reports `app: "claude-code"` with `idle`/`working`/`done`.
  **Verified** — `hc wait` captures a turn boundary reliably.
- **dialogs**: **folder trust** on a directory Claude Code has not seen before.
  It blocks the first message and `hc run` reports `first_message.sent:
  false`. Clear it with `hc keys <t> down` then `hc keys <t> enter`; the grant
  persists, so re-dispatch and the task goes through.
- **permissions**: scope the write access, e.g.
  `--allowedTools "Read Grep Glob Bash Write(<git-dir>/cross-review/**)"`.
  Claude Code will not prompt for allowed tools, so a reviewer never stalls on
  a permission prompt.
- **notes**: `--permission-mode plan` makes it read-only but also prevents it
  from writing its findings file, so it is not a substitute for scoping
  `Write`.

### codex (Codex CLI)

- **command**: `codex` — the npm shim (`npm i -g @openai/codex`), verified at
  `codex-cli 0.169.0`. It is on PATH through the npm bin directory. The Codex
  desktop app installs a separate copy under
  `%LOCALAPPDATA%\OpenAI\Codex\bin\<hash>\codex.exe`, where `<hash>` changes
  on every update, so that path cannot be used directly; the npm copy is the
  stable one.
- **print**: `codex exec "<PACKET>"` — verified present on this machine. Reads
  stdin when the prompt is `-`. Use this for L2 only; at L3 it cannot be
  watched or steered. `codex review` is a different, narrower print mode and is
  not this protocol.
- **prompt**: `argv`.
- **status**: **does not report agent status.** `hc get` shows `status: null`
  and `turn` stuck at 1 even while it is working. Consequence: `hc wait <t>`
  cannot detect a turn boundary — it waits for the process to exit, and the
  TUI stays alive at its prompt after finishing, so the wait only ever times
  out. **Collect a Codex review by waiting for its report message**, not by
  waiting on the terminal.
- **paste**: `hc send` pastes the task but does **not** submit it. Codex shows
  the text as `[Pasted Content N chars]` in its input box and waits. Send
  `hc keys <t> enter` once to submit. Claude Code, by contrast, submits the
  paste itself — the difference is per agent, so after any `hc send` to a
  reviewer, check the screen and press Enter if a pasted block is still
  pending.
- **dialogs**: **folder trust**, and it looks different from Claude Code's.
  Codex shows a "Folder access" panel naming the repository root, with
  `1. Trust and continue` and `2. Back to Agent Command Center`. The first
  option is already selected, so **`hc keys <t> enter` alone** clears it —
  no `down` needed. The trust is saved, so the next launch delivers the task
  normally.
- **notes**: **must run with `--no-daemon`** (including through a template),
  or its commands execute outside Core and the reviewer stops being a child.
  The flag is supported (`codex --help` lists it).
- **sandbox**: give it write access to the workspace and no approval prompts,
  or it will stall on a permission dialog when it writes its findings file
  and when it runs the delivery command:
  `-s workspace-write -a never`. A read-only sandbox (`-s read-only`) blocks
  the findings write.
- **skills**: it ships a built-in `review-agent` skill whose finding format is
  P0–P3 with a `No findings.` sentinel — the same format as the `review-agent`
  skill bundled in this toolkit, which makes the two vendors interchangeable.
  It also loads the shared `herdr-core` skill and used it for the handoff,
  unprompted.
- **skills reach**: Codex does **not** read `~/.claude/skills`. It reads
  `~/.codex/skills` only, so the shared skill repository is mirrored there
  with directory junctions. Run `sync-codex-skills.ps1` after adding,
  renaming, or removing a skill, or Codex will not see the new one.

### opencode

- **command**: `opencode.cmd` (npm shim) or `opencode2.cmd`.
- **print**: `opencode run --format json "<PACKET>"` — verified present on this
  machine. Use `--agent` to pick an agent if the default one prompts.
- **prompt**: `argv`. Verified as the controller side.
- **status**: reports `app: "opencode"` with `working`/`idle`.
  **Verified**.
- **dialogs**: none observed.
- **notes**: the binary also emits an OSC title, so the terminal title in the
  Herdr window shows the session title.

### dsh-tui (DeepSeek Harness TUI launcher)

- **command**: `dsh-tui --backend <dsh|claude|codex|plugin-backend> -- "<prompt>"`
  The alias `dst` is equivalent. The `--` separator passes the remaining
  arguments as a **literal prompt**, which is exactly the contract needed.
- **prompt**: `argv` after `--`. The launcher also takes a workspace path or
  URL as a positional target.
- **status**: **unverified** — depends on which backend is selected, since the
  backend determines which TUI is running underneath.
- **dialogs**: unknown.
- **notes**: the launcher can migrate sessions between `claude-code`, `codex`,
  `omp`, `zcode` and `grok-build`, and can boot a profile from
  `$DSH_HOME/profiles`. A different backend is a different model family,
  which is the point.

### dsh (profile launcher)

- **command**: `dsh --profile <name> -- "<prompt>"` boots a profile — an
  ordered stack of plugin-bundle patch layers — and passes the remaining
  arguments to the profile's app.
- **prompt**: `argv` after `--`.
- **status**: **unverified**.
- **dialogs**: unknown.

### pi

- **command**: `pi --provider <provider> --model <model> --thinking <level>`
  Put the model choice in the command, not in the packet.
- **prompt**: `argv`.
- **status**: **unverified**, and not installed on this machine.
- **dialogs**: unknown.

### Any other CLI agent

If an agent is not registered, try it anyway — the registry records what is
known, not what is allowed:

```sh
hc run --bg --json --name rev-<lens> --cwd "$REPO" <command> "<PACKET>"
```

Then check two things:

- `first_message.sent` must be `true`. If it is `false`, `hc read <t>` shows
  why — usually a startup dialog.
- `hc get <t>` shows `status`. A `null` status means the agent does not report
  OSC 7501; the review still works, but `hc wait` will wait for the process to
  exit rather than for a turn boundary, and `hc read` is how you collect the
  output.

If it works, add an entry here.

## Verifying a new agent as a reviewer

Before trusting an agent in the panel, run this once against a scratch repo:

```sh
# 1. does it take a prompt and start?
hc run --bg --json --name probe --cwd "$REPO" <command> "<PACKET>"
#    -> first_message.sent must be true

# 2. does it report status?
hc get <address> --json        # status.app / status.state

# 3. does it survive a wait, and does the report come back?
hc wait <address> --timeout 180
#    -> reason "message" means the report arrived

# 4. did it stay read-only?
git -C "$REPO" status --short   # only the findings file may be new
```

Then update this file with what you observed: the launch line, whether status
is reported, any dialog it raised, and any permission flag it needs to avoid
prompting.

**Do not trust an agent that only works one-shot.** `claude -p`, `codex exec`
and friends never report status, so a wait on them either blocks on the
process or returns nothing useful, and they cannot be steered or continued.
Interactive TUI mode is the requirement, not a preference.

## Choosing the reviewer

Prefer a reviewer whose model family differs from the author's. Same-family
reviewing shares the model's blind spots; a clean context alone does not fix
that.

When the only available reviewer shares the author's family, **say so and
record it** in the report — do not silently proceed, and do not refuse to run.
A weaker review that ran is more useful than no review, as long as its
weakness is visible.

## The author's side is symmetric

The controller can be any agent. This skill lives in `~/.claude/skills`, which
is read natively by Claude Code, read as a compatibility source by opencode,
and reachable by codex through directory junctions into `~/.codex/skills`. A
Claude Code session that writes the code can therefore dispatch an opencode or
codex reviewer through the same flow, with the same packet, and collect the
report the same way.
