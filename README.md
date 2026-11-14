# cross-review

A review toolkit for coding agents: **two skills** that make code review a
cross-model exercise instead of a model grading its own homework.

| Skill | What it does |
|---|---|
| [`cross-review`](skills/cross-review/SKILL.md) | The orchestration skill. States the change's intent, dispatches independent reviewer agents on different model families as parallel panes in one Herdr tab, rules on each finding, then fixes and re-reviews only the delta. |
| [`review-agent`](skills/review-agent/SKILL.md) | The finding contract. A read-only, defect-first review format — P0–P3 severities, a `No findings.` sentinel, and the rules that stop a reviewer from inventing its own evidence. |

They compose: `cross-review` runs the panel, `review-agent` gives the panel a
common language so two vendors' reports can be compared line by line.

## Why two skills instead of one

Because they answer different questions and are useful apart.

`cross-review` needs herdr-core, a git repository, and at least one other
agent CLI. `review-agent` needs nothing but an agent — it is a review
contract, and it improves any review, with or without a panel. Codex even
ships it built in.

Bundling them would have meant `review-agent` could never be installed on its
own, and the shared-contract idea would collapse into "one skill's internal
detail".

## Why cross-model review

Most "review this" prompts review with the same model that wrote the code.
That is the weakest form of review available: the reviewer shares the author's
blind spots. A clean context does not fix that — a different model does.

Measured on a single diff, same lens, same packet:

| Location | Claude Code | Codex | Verdict |
|---|---|---|---|
| a cancellation guard that only blocked one of four post-warehouse states | P1 | P1 | agreed, same line |
| a refund helper that can return a negative amount | P3 | P2 | agreed, **severity differs** |
| new public functions shipping without tests | P2 | P2 | agreed |
| half-cent rounding inconsistent on binary floats | P2 | — | **Codex missed it** |
| the project's money rule contradicting its own price helpers | P2 | — | **Codex missed it** |
| an unrelated file deleted in the same diff | P2 | P2 | both caught it |

**The union is the finding set, not the intersection.** Neither panel alone
was the answer.

## Installation

Install everything in the toolkit:

```bash
npx skills add https://github.com/laboberken/cross-review
```

Install one skill by name:

```bash
npx skills add https://github.com/laboberken/cross-review@cross-review
npx skills add https://github.com/laboberken/cross-review@review-agent
```

Or install by hand. Claude Code reads `~/.claude/skills` natively; opencode
reads it as a compatibility source; Codex reads `~/.codex/skills` only, so the
shared skill directory is mirrored there.

```bash
git clone https://github.com/laboberken/cross-review.git
cp -r cross-review/skills/* ~/.claude/skills/
sh ~/.claude/skills/cross-review/scripts/sync-codex-skills.sh
```

Windows PowerShell:

```powershell
git clone https://github.com/laboberken/cross-review.git
Copy-Item cross-review\skills\* "$env:USERPROFILE\.claude\skills\" -Recurse
pwsh -File "$env:USERPROFILE\.claude\skills\cross-review\scripts\sync-codex-skills.ps1"
```

Install the herdr-core reviewer templates — these carry the read-only contract
every reviewer runs under, plus each agent's launch line:

```bash
sh ~/.claude/skills/cross-review/scripts/install-templates.sh
```

```powershell
pwsh -File "$env:USERPROFILE\.claude\skills\cross-review\scripts\install-templates.ps1"
```

Optionally install the slash command:

```bash
mkdir -p ~/.config/opencode/commands
cp ~/.claude/skills/cross-review/commands/cross-review.md ~/.config/opencode/commands/
```

Restart your agent, or run `/reload`.

## Usage

```bash
/cross-review                            # git diff HEAD
/cross-review the auth module
/cross-review HEAD~3..HEAD
```

Or ask in plain language: "review this change with a different model", "run an
adversarial review of the login fix".

### How the panel works

1. The controller states the **intent** and what is out of scope, and checks
   the repository's own rules for contradictions.
2. It picks **lenses** by change size: 1 reviewer under 50 lines, 2 under 200
   lines or 5 files, 3 beyond that.
3. It creates one Herdr tab and adds one **pane per reviewer**, each an
   independent agent process launched through `hc`.
4. Each reviewer writes its findings to `.review/round-<N>/<lens>.md` and
   reports back with `hc send`.
5. The controller presents each lens's report **in its own section** — no
   merging, no cross-lens reranking — and rules on each individual finding:
   accept, reject, or defer, with a reason.
6. Accepted findings are fixed, a new baseline commit is landed, and the next
   round reviews **only the delta**. Cap: 3 rounds.

### Lenses

| Lens | Challenges |
|---|---|
| **Skeptic** | correctness and completeness — what breaks, what is unhandled, what is believed but unproven |
| **Architect** | structural fitness — does the design serve the goal, where do the couplings hurt, what breaks under scale |
| **Minimalist** | necessity and complexity — what can be deleted, what is being solved prematurely, what is the simplest path |

### Agents

`skills/cross-review/references/agents.md` is the registry: how to start each
agent as a reviewer, whether it reports status, how it takes a prompt, and
what startup dialogs it raises. Verified for Claude Code, Codex, and opencode;
unverified entries for `dsh-tui`, `dsh`, and `pi`.

Each agent needs its own herdr-core template, because the template carries
both the read-only contract and that agent's launch line.

## Safety valves

The skill stops and reports instead of dispatching when:

- The repository's rules contradict each other. Reviewers read the rules the
  same way the rules are broken, so this is the controller's job.
- No reviewer runs on a different model family than the author. It says so and
  records it rather than silently proceeding.
- The test command in the repository's docs does not run. A reviewer that
  cannot run tests reports unverified claims.
- A reviewer's report contains a number that no command produced.

The skill never closes, kills, or removes a reviewer's terminal or tab. The
user closes them, so the transcript stays readable.

## Repository layout

```text
.
├── skills/
│   ├── cross-review/
│   │   ├── SKILL.md                 # name: cross-review
│   │   ├── references/
│   │   │   ├── lenses.md            # Skeptic / Architect / Minimalist
│   │   │   ├── agents.md            # agent registry
│   │   │   ├── task-packet.md       # the packet handed to a reviewer
│   │   │   └── troubleshooting.md   # measured failure modes
│   │   ├── commands/cross-review.md # slash command
│   │   ├── templates/               # herdr-core reviewer templates
│   │   ├── examples/                # measured sessions
│   │   └── scripts/                 # install and mirror helpers
│   └── review-agent/
│       └── SKILL.md                 # name: review-agent
├── .github/workflows/validate.yml
├── LICENSE
└── README.md
```

## License

MIT. See [LICENSE](LICENSE).
