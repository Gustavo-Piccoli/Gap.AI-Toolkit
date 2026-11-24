# Review: todo-api-rate-limit — Cycle v1

> Fictional example produced with `gap-review-plan` on [`plano-todo-api-rate-limit.md`](./plano-todo-api-rate-limit.md). Severity labels stay in Portuguese, as the skill emits them.

## 1. Summary
- Plan file: `plano-todo-api-rate-limit.md`
- Review cycle: v1 (2026-11-20)
- Open findings: 1 Crítico, 1 Importante, 1 Menor
- Verdict: **PRECISA DE MAIS REVISÃO**

## 3. Findings

### Correctness

**F1 — Crítico — `INCR` and `EXPIRE NX` are not atomic**
- Plan section(s) affected: Section 6, Phase 2, item 2
- Problem: the plan runs two separate Redis commands. If the process dies between them, the key never expires.
- Failure scenario: a worker restart right after `INCR` leaves `rl:{client}:{minute}` without TTL; because the key name contains the minute, it is never reused, but keys accumulate in Redis indefinitely.

**F2 — Importante — `Retry-After` computed from the wrong clock**
- Plan section(s) affected: Section 2, decision 3; Section 8, criterion 3
- Problem: the plan does not say whether the window boundary uses the API host clock or Redis `TIME`. With several API hosts, skewed clocks produce different windows for the same key.
- Failure scenario: two hosts 2 s apart compute different `epoch_minute` values near the boundary, so a client can send up to 2 × limit requests in about one minute.

### Testability

**F3 — Menor — "Redis down" test has no defined setup**
- Plan section(s) affected: Section 6, Phase 1, item 1
- Problem: `fakeredis` does not simulate a connection failure by default; the plan does not say how to inject it.
- Failure scenario: the executor writes a test that never actually exercises the fail-open path and passes anyway.

## 4. Verdict
**PRECISA DE MAIS REVISÃO** — 1 Crítico, 1 Importante, 1 Menor. F1 must be fixed before execution (use a pipeline/`MULTI` or a Lua script); F2 needs a decision on the time source.

## 5. Next step
```
/gap-fix-plan plano-todo-api-rate-limit.md revisao-todo-api-rate-limit-v1.md
```
