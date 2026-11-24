# Plan template

ALWAYS use this exact structure when generating a plan. Write the plan in English. Replace the bracketed guidance with real content. Section 7 may be omitted only if the plan genuinely has no delegable tasks; all other sections are mandatory.

---

# Plan: [short title]

## 1. Executor Persona
[Who the executing AI must be, in one or two lines. Example: "Senior software engineer specialized in DDD refactoring of Node.js codebases."]

## 2. Context
[Fully self-contained. Project description, stack, relevant files and directories with paths, current state, and every decision confirmed during plan creation that the executor must know. The executor has no access to the creation conversation — anything not written here does not exist for it.]

## 3. Objective
[One sentence stating what must exist when the plan is done, followed by whatever detail is necessary.]

## 4. Constraints & Non-Goals
[What must not be done, and what is explicitly out of scope. This prevents the executor from inventing work.]

## 5. Execution Directives
Execute with minimal verbosity in responses and reasoning. Keep all checklists in this file updated as work progresses.
[Add here ONLY directives specific to this plan, if any. Generic execution behavior — agent orchestration, resume logic, review discipline — is provided by gap-execute-plan and must not be duplicated here.]

## 6. Master Checklist
[Phases and tasks in execution order. Agent Tasks (section 7) must be dispatched from here: place an explicit dispatch item in the phase where the agents should run, so the executor knows exactly when to launch them and which ones run in parallel.]

### Phase 1 — [name]
- [ ] [task]
- [ ] [task]

### Phase 2 — [name]
- [ ] Dispatch Agent tasks A and B (parallel); integrate their returns
- [ ] [task]

## 7. Agent Tasks
[For each parallelizable or delegable task:]

### Agent task A — [name]
- Model: best available Sonnet, effort High
- Instruction: [complete standalone instruction — the agent sees only this]
- Checklist:
  - [ ] [step]
  - [ ] [step]
- Return: [exactly what the agent must report back to the coordinator]

## 8. Acceptance Criteria
[Objective, verifiable conditions of success. Whenever applicable, prefer machine-checkable criteria — concrete commands with expected outcomes (e.g. "`npm test` passes with no failures", "build compiles with no warnings") — over subjective judgments. A criterion a machine can verify removes subjectivity from the Final Review.]
- [ ] [criterion]
- [ ] [criterion]

## 9. Final Review
- [ ] Review every artifact produced (code, files, configs) against the Acceptance Criteria.
- [ ] Fix any divergence found and re-verify.
- [ ] Only then declare the plan complete.
