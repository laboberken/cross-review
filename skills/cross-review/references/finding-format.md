# Finding format

The one canonical text for how a reviewer reports. Every referee template
carries this section verbatim; `validate.yml` compares each template against
this file and fails on any difference. Change the wording here and the build
tells you which templates to update.

This file defines the **shared** contract only. Each template adds its own
role rules — do not modify files, do not delegate, check the premise — which
are the same in spirit but written per agent.

## Flag a finding only when all of these are true

- It affects correctness, security, performance, or maintainability in a
  meaningful way.
- It is discrete and actionable.
- It was introduced by the reviewed change.
- The affected scenario or call path can be demonstrated from the code.
- The author would probably fix it if they knew about it.

Do not flag speculative concerns, pre-existing problems, intentional behaviour
changes, or style nits that do not obscure the code.

## Verify before you claim

Every number, output, and error message in a finding must come from a command
you actually ran. Do not write a plausible-looking example you did not
observe. If you did not run it, do not say "verified".

When the repository has a test command, run it and paste what it printed. A
failing test is a finding.

## Write the result

Open with the header, on these exact lines:

```
AXIS: <correctness|spec|standards> | LENS: <skeptic|architect|minimalist>
COVERED: what this review inspected
NOT COVERED: what it did not
```

Your task names the axis and the lens. Use them verbatim. If the task names
neither, write `AXIS: undeclared | LENS: undeclared` rather than guessing — a
guessed axis is worse than a declared absence.

The header is the only part of this contract that is optional to a harness.
Codex ships its own copy of this format; a report that omits the header is
still a valid report, filed as axis-undeclared.

When your axis is `spec`, every finding must quote the spec line it checks
against. Without the quote, the finding is an opinion about scope, not a
finding.

Present findings after the header, ordered by severity. One entry per issue:

```
[P1] Imperative finding title - path/to/file.rs:line
```

Follow the title with one short paragraph explaining the affected scenario and
why the behaviour is wrong. Keep the cited range as small as possible and make
sure it overlaps the reviewed diff.

Use these priorities:

- `P0`: universal release blocker or critical failure.
- `P1`: urgent defect that should be fixed next.
- `P2`: ordinary defect that should be fixed.
- `P3`: low-impact issue that is still worth fixing.

If there are no qualifying findings, say `No findings.` Do not invent a
finding to fill the result.

After the findings, add a brief overall assessment and mention any material
test gaps or residual risks.
