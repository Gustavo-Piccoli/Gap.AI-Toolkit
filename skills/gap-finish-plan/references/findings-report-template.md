# Findings report template

ALWAYS use this exact structure when generating a findings report. Write it in English, like the plan. Replace the bracketed guidance with real content. Section 2 is omitted entirely for cycle v1 (there is no prior cycle to compare against). This file is only ever created when at least one finding is open (see SKILL.md step 9) — a clean cycle is reported in conversation only.

---

# Finish review: [plan name] — Cycle v[N]

## 1. Summary
- Plan file: `plano-<name>.md`
- Finish cycle: v[N] ([date])
- Base ref / scope: [e.g. "git diff `a1b2c3d`..working tree" or "files pointed to by the user: ..."]
- Open findings: [count by severity, e.g. "1 Crítico, 2 Importante, 1 Menor"]
- Verdict: **[IMPLEMENTAÇÃO OK | PRECISA DE CORREÇÃO]**

## 2. Status of previous findings
[Omit this entire section for v1. For v2+, one row per finding carried from the previous report — including ones now resolved.]

| ID | Original severity | Status | Justification |
|----|----|----|----|
| F1 | Importante | Resolved | [what changed in the diff that fixes it] |
| F2 | Crítico | Not resolved | [what's still broken] |
| F3 | Menor | Partially resolved | [what improved, what's still open] |

## 3. Findings
[One entry per OPEN finding only — new this cycle, or carried forward (Not resolved / Partially resolved) under its original ID. Resolved findings do not appear here. Group by dimension.]

### [Dimension name, e.g. "Acceptance Criteria & checklist compliance" / "Code quality & conventions" / "Scope adherence" / "Regression risk & consistency" / "Automated tests" / "Functional verification"]

**F[n] — [Crítico|Importante|Menor] — [one-line title]**
- Evidence: [file/line, diff hunk, test name + failure output, or the steps taken for functional verification]
- Problem: [what is wrong, precisely]
- Failure scenario: [concrete situation in which this breaks, or the concrete gap versus the plan]
- Suggested direction: [brief pointer to what/roughly where to change — not full code, not a mandate]

[repeat for each finding in this dimension, then for each other dimension with open findings]

## 4. Verdict
[Restate the verdict and the severity counts from section 1, one short paragraph explaining what's blocking it if not clean.]

## 5. Next step
```
/gap-finish-plan <plan-path>
```
(after the findings above are fixed)
