# Review report template

ALWAYS use this exact structure when generating a review report. Write it in English, like the plan. Replace the bracketed guidance with real content. Section 2 is omitted entirely for cycle v1 (there is no prior cycle to compare against).

---

# Review: [plan name] — Cycle v[N]

## 1. Summary
- Plan file: `plano-<name>.md`
- Review cycle: v[N] ([date])
- Open findings: [count by severity, e.g. "2 Crítico, 1 Importante, 3 Menor"]
- Verdict: **[PRONTO PARA EXECUÇÃO | PRECISA DE MAIS REVISÃO]**

## 2. Status of previous findings
[Omit this entire section for v1. For v2+, one row per finding carried from the previous report — including ones now resolved.]

| ID | Original severity | Status | Justification |
|----|----|----|----|
| F1 | Importante | Resolved | [what changed in the plan that fixes it] |
| F2 | Crítico | Not resolved | [what's still missing] |
| F3 | Menor | Partially resolved | [what improved, what's still open] |

## 3. Findings
[One entry per OPEN finding only — new this cycle, or carried forward (Not resolved / Partially resolved) under its original ID. Resolved findings do not appear here. Group by dimension.]

### [Dimension name, e.g. "Internal consistency"]

**F[n] — [Crítico|Importante|Menor] — [one-line title]**
- Plan section(s) affected: [e.g. "Section 6, Phase 2" / "Section 4, item 3"]
- Problem: [what is wrong, precisely — no proposed fix]
- Failure scenario: [concrete situation in which this breaks execution]

[repeat for each finding in this dimension, then for each other dimension with open findings]

## 4. Verdict
[Restate the verdict and the severity counts from section 1, one short paragraph explaining what's blocking it if not clean.]

## 5. Next step
```
/gap-fix-plan <plan-path> <this-report-path>
```
