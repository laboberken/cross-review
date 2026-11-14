# Reviewer lenses

Three distinct roles. Each reviewer adopts one lens **exclusively** — a
reviewer that hedges across lenses finds less than two reviewers that commit.

Adapted from the lens structure in `poteto/noodle@adversarial-review`
(skills.sh, 1.6K installs), which separates role decomposition from the
transport that runs the reviewer.

## Skeptic

Challenges **correctness and completeness**.

- What inputs, states, or sequences will break this?
- What error paths are unhandled or silently swallowed?
- What race conditions or ordering dependencies exist?
- What does the author believe is true that is not proven?
- Where is "it works on my machine" masquerading as verification?

Report a finding when you can name the input, the path, and the wrong outcome.

## Architect

Challenges **structural fitness**.

- Does the design actually serve the stated goal, or a goal the author
  assumed?
- Where are the coupling points that will hurt when requirements shift?
- What boundary violations exist — where does responsibility leak between
  components?
- What implicit assumptions about scale, concurrency, or ordering will break
  first?

Report a finding when you can name the boundary that leaks or the assumption
that breaks.

## Minimalist

Challenges **necessity and complexity**.

- What can be deleted without losing the stated goal?
- Where is the author solving problems they do not have yet?
- What abstractions exist for a single call site?
- Where is configuration or flexibility added without a concrete second use?
- Is this the simplest possible path to the outcome, or the path that felt most
  thorough?

Report a finding when you can name the specific thing to delete or defer.

## Assembling a lens into a reviewer prompt

The prompt is five ingredients, in this order:

1. the **stated intent** — what the author is trying to achieve, and what
   success looks like
2. the **lens** — the full text above, not a summary
3. the **scope** — the exact diff command and the baseline sha
4. the **project rules** — the repository's own `AGENTS.md`, with its test
   command
5. the **delivery clause** — where to write the findings and how to report back

Plus the standing instructions from `review-agent/SKILL.md`: the finding
format, the flagging bar, the "every number must come from a command's output"
rule, and the "check the premise you were given" rule.

## The intent statement

The intent is written by the controller, not the reviewer, and it is passed
verbatim. It must say:

- what the change is trying to achieve
- what would count as success
- what is explicitly **out of scope** for this change

Without an intent, a reviewer can only check rules, and rule-checking produces
style findings dressed up as defects.

## Common failure mode to avoid

A reviewer that was given the intent but not the scope will review the whole
repository, or the wrong change. Give it a diff command and a baseline sha, and
in the packet tell it to check that what it is about to review is what the
scope says — a reviewer that silently reviews a different diff is worse than
no reviewer.
