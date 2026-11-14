# cross-review

A cross-model adversarial code review skill for OpenCode, Claude Code, and
Codex, orchestrated over [herdr-core](https://github.com/herdrdev/herdr-core).
It states the change's intent, dispatches independent reviewer agents on
different model families as parallel panes in one Herdr tab, rules on each
finding, then fixes and re-reviews only the delta.

## Why another review skill?

Most "review this" prompts review with the same model that wrote the code.
That is the weakest form of review available: the reviewer shares the
author's blind spots. A clean context does not fix that — a different model
does.

This skill encodes the parts that hold up:

- **Cross-model, not just cross-process** — reviewers run on a different model
  family than the author. Isolation buys a clean context; a different model
  buys different assumptions.
- **A panel, not a reviewer** — two reviewers with different blind spots
  found different defects on the same diff. The union is the finding set; a
  single panel's blind spot is not.
- **Intent first** — reviewers challenge whether the work achieves the stated
  intent, not whether the intent itself is right. Without an intent a review
  can only check rules, and rule-checking produces style findings dressed up
  as defects.
- **Roles, not dimensions** — Skeptic, Architect, and Minimalist are
  behavioural stances that find different things. "Standards" and "Spec" are
  two axes of one change; lenses are three different reviewers.
- **Location is the finding, severity is an opinion** — the same defect at
  the same line came back as P3 from one model and P2 from another.
- **Re-derive every number** — reviewers fabricate plausible examples. The
  author inherits them if they do not check.
- **Round cap** — three rounds. Past that, further rounds surface stylistic
  noise.

## Installation

Install as a global skill, from any of the three agents:

```bash
npx skills add https://github.com/laboberken/cross-review
```

Or clone it:

```bash
git clone https://github.com/laboberken/cross-review.git
cd cross-review
```

Claude Code reads `~/.claude/skills` natively. opencode reads it as a
compatibility source. Codex reads `~/.codex/skills` only, so the shared skill
repository is mirrored there:

```bash
# Claude Code and opencode
mkdir -p ~/.claude/skills/cross-review
cp -r SKILL.md references ~/.claude/skills/cross-review/

# Codex (mirror)
sh scripts/sync-codex-skills.sh
```

Windows PowerShell:

```powershell
New-Item -ItemType Directory -Force "$env:USERPROFILE\.claude\skills\cross-review"
Copy-Item SKILL.md "$env:USERPROFILE\.claude\skills\cross-review\SKILL.md"
Copy-Item references "$env:USERPROFILE\.claude\skills\cross-review\" -Recurse

pwsh -File scripts\sync-codex-skills.ps1
```

Install the herdr-core reviewer templates — these carry the read-only
contract every reviewer runs under, plus each agent's launch line:

```bash
sh scripts/install-templates.sh
```

```powershell
pwsh -File scripts\install-templates.ps1
```

Optionally install the slash command:

```bash
mkdir -p ~/.config/opencode/commands
cp commands/cross-review.md ~/.config/opencode/commands/cross-review.md
```

`review-agent` — the shared finding format that makes two vendors
machine-comparable — lives in its own repository:

```bash
git clone https://github.com/laboberken/review-agent.git
cp -r review-agent/SKILL.md ~/.claude/skills/review-agent/SKILL.md
```

Restart your agent, or run `/reload`.

## Usage

```bash
/cross-review                            # git diff HEAD
/cross-review the auth module
/cross-review HEAD~3..HEAD
```

Or ask in plain language: "review this change with a different model",
"run an adversarial review of the login fix".

### How it works

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
   round reviews **only the delta**.

### Lenses

| Lens | Challenges |
|---|---|
| **Skeptic** | correctness and completeness — what breaks, what is unhandled, what is believed but unproven |
| **Architect** | structural fitness — does the design serve the goal, where do the couplings hurt, what breaks under scale |
| **Minimalist** | necessity and complexity — what can be deleted, what is being solved prematurely, what is the simplest path |

### Agents

`references/agents.md` is the registry: how to start each agent as a
reviewer, whether it reports status, how it takes a prompt, and what startup
dialogs it raises. Verified entries for Claude Code, Codex, and opencode;
unverified entries for `dsh-tui`, `dsh`, and `pi`.

Each agent needs its own herdr-core template, because the template carries
both the read-only contract and that agent's launch line. `templates/`
contains the ones for Claude Code and Codex.

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
├── SKILL.md                     # skill definition (name: cross-review)
├── commands/
│   └── cross-review.md          # slash command
├── references/
│   ├── lenses.md                # the three lens definitions
│   ├── agents.md                # agent registry: launch line, status, dialogs
│   ├── task-packet.md           # the packet handed to a reviewer
│   └── troubleshooting.md       # measured failure modes and their fixes
├── templates/
│   ├── reviewer.md              # herdr-core template for Claude Code
│   └── reviewer-codex.md        # herdr-core template for Codex
├── examples/
│   ├── panel-two-models.md      # two reviewers, two model families, one diff
│   ├── incremental-rereview.md  # three rounds, and the round that mattered
│   └── agent-behaviour-matrix.md
├── scripts/
│   ├── install-templates.ps1
│   ├── install-templates.sh
│   ├── sync-codex-skills.ps1
│   └── sync-codex-skills.sh
├── .github/workflows/
│   └── validate.yml
├── LICENSE
└── README.md
```

## License

MIT. See [LICENSE](LICENSE).
