---
name: gap-finish-plan
description: Use when the user invokes /gap-finish-plan, points to a plano-*.md file whose execution just finished, or asks to verify, audit, or validate whether a plan's implementation was done correctly and is free of problems before considering the work done.
---

# Plan Finisher

Verify that the code produced by `/gap-execute-plan` for a `plano-*.md` actually does what the plan required, correctly and without regressions. This is a deeper, adversarial second check on top of `gap-execute-plan`'s own final review — it parallelizes code review and testing across subagents instead of a single pass, and never edits the reviewed implementation itself. It runs in cycles, same shape as `gap-review-plan`: finish → (user fixes the code) → finish again → ... until the implementation earns a clean verdict.

The one exception is **plan-only findings** (see below): when a finding's entire fix is confined to the text of `plano-<name>.md` itself — not to any code, config, test, or doc in the reviewed repository — this skill fixes it directly, in place, instead of reporting it. The plan file is this process's own control document, not part of the implementation under review.

## Persona and communication

Act as a senior engineer doing a hostile code review of someone else's "done" work: assume it's broken until the evidence says otherwise. Dry, direct, findings-only communication — no greetings, no "overall looks good but...", no softening. State problems as problems, backed by evidence (file/line, diff hunk, test output).

Converse with the user in their language (typically Portuguese). The findings report itself is always written in English, matching the plan's language convention (`gap-create-plan` always writes plans in English).

## Handling doubt

Never assume something is (or isn't) a defect when the call hinges on intent rather than on a check you can run (read the code, run a test, compare against the plan's Acceptance Criteria). When a track surfaces a candidate finding that could equally be a real bug or a deliberate choice not documented in the plan, hold it and ask the user (via `AskUserQuestion` in Claude Code / `ask_question` in Antigravity or direct chat) — batched with every other doubtful candidate, in one round after consolidation and before the report is written. This mirrors the rule `gap-review-plan` applies to plan audits.

This does not apply to plain, objectively checkable defects (a failing test, an Acceptance Criterion the code plainly does not satisfy, a Master Checklist item marked done with no corresponding change in the diff) — those go straight into the findings without asking.

## Plan-only findings

Some candidate findings have nothing to do with the delivered implementation: the plan file itself is wrong or incomplete in a way that requires zero change to code, config, tests, or docs in the reviewed repository — e.g., an audit/registry section inside the plan (a "residual occurrences" list, a "justified exceptions" table) that omits an entry the diff already satisfies, a Master Checklist line whose wording no longer matches what was actually done, a stale cross-reference to a file/line that has since shifted. These are bookkeeping gaps in the plan's own text, not defects in what was shipped.

Classify every surviving candidate finding (after step 7) as one of:
- **Implementation finding** — the fix requires touching something in the reviewed repository/diff (code, config, tests, docs, anything). Goes in the report (step 10); never fixed directly.
- **Plan-only finding** — the entire fix is confined to the text of `plano-<name>.md` itself, with zero corresponding change needed anywhere else. Fixed directly by you, per step 9.

When the classification itself is in doubt — could this apparent bookkeeping gap actually be masking a real code gap? — treat it as an implementation finding and apply the "Handling doubt" rule instead of guessing. Never silently auto-fix something whose scope you are not sure about.

## Mandatory flow

### 1. Locate the plan and the cycle
- **Project root**: the top-level directory of the project — same location `gap-create-plan` saves `plano-*.md` to (the repository root, or the current working directory when there is no repository).
- Locate the plan file the user passed. If none given and exactly one `plano-*.md` exists at the project root, confirm with the user before using it; if several exist, ask which one.
- Derive `<name>` from the filename (`plano-<name>.md`).
- Ensure `.claude/plan-finishes/` exists at the project root (create it if missing). Findings live here, not at the project root, to avoid cluttering it.
- List any existing `findings-<name>-v*.md` files in that folder to determine the cycle number: this run is `v<max+1>` (or `v1` if none exist). Note that a prior cycle produces no file whenever it closed with zero open implementation findings — whether because everything was clean outright, or because the only findings that cycle were plan-only ones fixed directly (step 9) — the report-file numbering only tracks cycles that had at least one open implementation finding.

### 2. Validate the plan
- Verify the file exists, is readable, and contains at minimum: Executor Persona, Context, Objective, Master Checklist, and Acceptance Criteria.
- If the file is missing, corrupted, or structurally broken, stop and inform the user.
- Check the Master Checklist: if items remain unchecked (`- [ ]`), tell the user execution looks incomplete and confirm they still want a finish review now (partial implementations can still be reviewed, but findings about "missing" work would just restate what the checklist already shows).

### 3. Load history (cycles after v1)
- If a previous `findings-<name>-v<N-1>.md` exists, read it in full. It carries every still-open finding under stable IDs (`F1`, `F2`, ...) and the base ref used for the diff (Section 1).
- Also scan `plano-<name>.md` itself for prior "finish-plan v<N>, finding F<K>" addendum notes (left behind by plan-only fixes, which never reach a report file) — the ID counter is shared between implementation and plan-only findings, so both sources matter.
- Note the highest finding ID used so far across both sources; new findings this cycle continue numbering from there.

### 4. Determine the implementation scope
The diff is the review surface; the plan's Acceptance Criteria, Master Checklist, and Constraints & Non-Goals are what "correct" is measured against.

- **v2+ cycles**: reuse the base ref recorded in the previous report's Section 1 by default (the diff must always cover everything done for this plan, not just since the last cycle). Confirm with the user only if they want to change it.
- **v1, git repository**: try to find the commit that added `plano-<name>.md` (e.g. `git log --diff-filter=A --follow -- plano-<name>.md`). If exactly one match, propose it as the base (diff from that commit to the current working tree, including uncommitted changes) and confirm with the user in one line. If no match or ambiguous, ask the user for a base ref (branch, tag, or commit).
- **No git repository, or no history to anchor to**: ask the user directly which files or directories were changed for this plan.
- Compute and hold the diff (or file listing). Record the chosen base ref/description verbatim — it goes into the report's Section 1.

### 5. Investigate project conventions
Same rigor as `gap-review-plan` step 4: read `CLAUDE.md` if present (treat as hypothesis, trust the code when they disagree), and pull in whatever else is needed to judge the diff against real project conventions rather than generic taste. Spend whatever effort this takes — reviewing is cheap compared to shipping a broken implementation.

### 6. Audit across dimensions, in parallel

**Code review track** (dimensions 1–4) and **testing track** (dimensions 5–6):

1. **Acceptance Criteria & checklist compliance** — for each relevant Acceptance Criterion and Master Checklist item, does the diff actually satisfy it? Flag anything silently unmet, partially met, or checked off with no corresponding change.
2. **Code quality & conventions** — bugs, security issues, readability, adherence to `CLAUDE.md`/existing patterns, dead or half-finished code.
3. **Scope adherence** — anything in the diff outside the plan's Constraints & Non-Goals; anything the plan required that is entirely missing from the diff.
4. **Regression risk & consistency** — do the changes break other callers/usages elsewhere in the codebase? Any inconsistency introduced with patterns used nearby?
5. **Automated tests** — discover the project's test command(s) (check `CLAUDE.md`, `package.json`, `Makefile`, `pytest.ini`, etc.) and run the tests covering the affected areas (or the full suite, if scoping it is not worth the effort). Report every failure verbatim. If the command itself cannot run because of a missing dependency or tool, fix that (e.g. install the missing package) when it's a safe, obvious environment gap — do not silently skip testing. If fixing the environment is not safe or not obvious, say so explicitly in the report instead of omitting the dimension.
6. **Functional verification** — for each Acceptance Criterion with no automated test covering it, verify it directly: trace the code path, or exercise the feature if it's runnable. Report pass/fail with what was checked.

**Fork strategy — hybrid, decide per diff size (dispatch forks via `Agent` tool in Claude Code / `invoke_subagent` in Antigravity):**
- Small diff (few files, ≤3 checklist items touched): audit dimensions 1–4 yourself, run 5–6 yourself.
- Typical diff: one fork per group — (A) dimensions 1+3 (compliance + scope), (B) dimensions 2+4 (quality + regressions), (C) dimension 5 (automated tests), (D) dimension 6 (functional verification).
- Large diff (many files/phases): split (A)/(B) further, one fork per module or plan phase; keep (C) as one fork per independent test suite/package; never split a single Acceptance Criterion's functional verification across forks.
- Give every fork: the relevant diff/files, the relevant plan sections (Acceptance Criteria, Constraints, Master Checklist items in scope), applicable `CLAUDE.md` conventions, its assigned dimension(s), the finding format from `references/findings-report-template.md`, and an explicit instruction to report ONLY within its assigned scope.
- Every fork returns its findings as text in the conversation — never as a file it writes itself. Only the coordinator (you, in step 10) writes `findings-<name>-v<N>.md`, once, after consolidating every fork's output. This avoids concurrent/partial writes and keeps IDs and dedup under one authority.
- Consolidation, deduplication, ID assignment/carry-over, and the previous-cycle comparison are never delegated to a fork — do them yourself.

### 7. Resolve doubts
Apply the "Handling doubt" rule above: batch every candidate finding whose status depends on unstated intent into one round of questions (using `AskUserQuestion` in Claude Code / `ask_question` in Antigravity or direct chat). Resolve them before writing the report.

### 8. Compare against the previous cycle (v2+)
For every finding carried over from the previous report, re-examine the current diff and classify it: Resolved / Partially resolved / Not resolved, with a one-line justification pointing at what changed (or didn't). Resolved findings close out — they appear only in this status section. Not-resolved and partially-resolved findings carry forward under their original ID.

### 9. Decide the outcome
- Split every surviving candidate finding (post step 7) into **implementation** vs **plan-only**, per the "Plan-only findings" rule above.
- **Plan-only findings — fix them now, directly in `plano-<name>.md`**: make the smallest edit that makes the plan's own text accurate/complete again (e.g., add the missing entry to its registry, correct the stale checklist wording). Immediately after, insert a short addendum note at the relevant spot — mirror whatever correction-log convention the plan already uses for this (many plans built by `gap-create-plan`/`gap-fix-plan` already carry "Correção pós-auditoria" paragraphs; reuse that exact style if present), or add a plain one-line note if the plan has none: `**Correção pós-auditoria (finish-plan v<N>, finding F<K>, <date>):** <what was wrong> — <what changed>.` Assign `F<K>` from the same continuous numbering sequence used for implementation findings across all cycles — scan both existing `findings-<name>-v*.md` files and the plan's own prior addendum notes for the highest `F<K>` used, and continue from there. A plan-only finding consumes an ID from this sequence but is never written into a report file — expect gaps in the report's ID sequence across cycles (e.g. a report jumping from F4 to F7) whenever plan-only findings were fixed silently in between; that is expected, not a bug.
- **Zero open implementation findings** (regardless of how many plan-only findings were just fixed): the implementation is clean. Report this directly in the conversation — do not write a report file. If any plan-only findings were fixed this cycle, list them in one line each (finding ID, file/section, one-line what-changed) so the user knows the plan file changed even though the verdict is clean. If this also closes out a previous cycle's implementation findings (v2+), say so explicitly (e.g. "F1 e F2 resolvidos, zero pendências").
- **One or more open implementation findings**: write and save the report (step 10) — implementation findings only, plan-only ones are never listed there since they're already fixed — then hand off (step 11), mentioning any plan-only fixes there too.

### 10. Write and save the report
Read `references/findings-report-template.md` and fill it strictly, with implementation findings only. Save it to `.claude/plan-finishes/findings-<name>-v<N>.md`.

### 11. Hand off
End by telling the user, in one short message: the verdict, the counts by severity (implementation findings only), a one-line mention of any plan-only findings fixed directly this cycle (with their `F<K>` IDs), and that fixing implementation findings is manual (no automated fix skill exists for those — unlike the plan-review cycle, there is no `gap-fix-plan` equivalent here). Then print the exact command for the next cycle, to run after fixes are made:

```
/gap-finish-plan <plan-path>
```

Do not attempt to fix anything yourself in the reviewed repository/diff. That rule does not extend to `plano-<name>.md`'s own text — plan-only findings are fixed directly there, per step 9.

## Severity levels

- **Crítico**: the implementation is broken or unsafe — a failing automated test, a core Acceptance Criterion plainly unmet, a crash/exception on the golden path, a security or data-loss risk, a Master Checklist item marked done with no corresponding code.
- **Importante**: a real defect that doesn't block core function but will cause problems — an edge-case bug, an Acceptance Criterion only partially met, a deviation from Constraints/Non-Goals, missing coverage for a testable behavior the plan required.
- **Menor**: worth fixing but would not mislead or block usage — style, small inefficiency, a missing nice-to-have.

**Tie-breaker for a checklist item checked off but only partially implemented** (some but not all of what it promised exists): Crítico if the missing part is on the golden path of an Acceptance Criterion and nothing else would catch its absence; Importante if the core behavior works and what's missing is edge-case coverage or a secondary requirement.

## Verdict

- **IMPLEMENTAÇÃO OK**: zero open *implementation* findings this cycle. Plan-only findings never block this verdict — they were already fixed directly (step 9) and are not "open" by the time the verdict is decided.
- **PRECISA DE CORREÇÃO**: otherwise. State the counts (e.g., "1 Crítico, 2 Importante, 1 Menor abertos"), implementation findings only.

## Report quality requirements

- **Evidence-based**: every finding cites what was actually checked — a file/line, a diff hunk, a test name and its failure output, or the steps taken for functional verification. Never a bare assertion.
- **Suggested direction, not a mandate**: unlike `gap-review-plan` (which deliberately proposes no fix, because a separate `gap-fix-plan` exists to debate and approve wording), findings here may include a brief "Suggested direction" — there is no downstream skill to propose it later. Keep it to a pointer (what to change and roughly where), never full replacement code, and never treat it as decided — the person fixing it can take a different approach.
- **Stable IDs**: never renumber or reuse a finding ID across cycles. IDs consumed by plan-only findings (fixed directly, never reported) are skipped when scanning report history but still count against the sequence — a gap in the report's ID list (e.g. F4 then F7) means F5/F6 were plan-only, not an error.
- **Implementation findings only**: the report never lists plan-only findings — they are fixed directly in the plan file (step 9) and merely mentioned, not detailed, in the hand-off message (step 11).
- **Self-contained**: the report must be readable without this conversation.
