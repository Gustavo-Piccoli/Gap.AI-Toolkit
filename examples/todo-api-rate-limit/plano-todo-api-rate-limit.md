# Plan: Per-client rate limiting for the Todo API

> Fictional example produced with `gap-create-plan`. The project, files and numbers are invented to show the format.

## 1. Executor Persona
Senior Python backend engineer experienced with FastAPI middleware and Redis.

## 2. Context
- Project: `todo-api`, a FastAPI service (Python 3.12) exposing `/todos` CRUD endpoints. Entry point: `app/main.py`; routers in `app/routers/`; settings in `app/settings.py` (pydantic-settings, env prefix `TODO_`).
- Clients authenticate with an `X-Api-Key` header, validated in `app/auth.py::require_api_key`, which returns the client id.
- Redis 7 is already a dependency (`app/cache.py::get_redis()`), used for response caching.
- Tests: `pytest` + `httpx.AsyncClient` in `tests/`; Redis is replaced by `fakeredis` in `tests/conftest.py`.
- Decisions confirmed during the interview:
  1. Limit is per API key, not per IP.
  2. Fixed window of 60 s; default 100 requests, configurable via `TODO_RATE_LIMIT_PER_MINUTE`.
  3. On limit: HTTP 429 with `Retry-After` (seconds until the window resets).
  4. `/health` is never limited.
  5. If Redis is unavailable, requests are allowed (fail open) and a warning is logged.

## 3. Objective
Every authenticated request is counted per API key in Redis, and requests above the configured limit in the current minute get HTTP 429 with a correct `Retry-After` header.

## 4. Constraints & Non-Goals
- Do not change the authentication flow or the public response schema of existing endpoints.
- No sliding-window or token-bucket algorithm in this plan.
- No new infrastructure (no API gateway, no new Redis instance).

## 5. Execution Directives
Execute with minimal verbosity in responses and reasoning. Keep all checklists in this file updated as work progresses.
- Write the failing tests of Phase 1 before any production code.

## 6. Master Checklist

### Phase 1 — Tests first
- [ ] Add `tests/test_rate_limit.py` covering: under limit (200), at limit + 1 (429), `Retry-After` value, `/health` exempt, Redis down (fail open).
- [ ] Run `pytest tests/test_rate_limit.py` and confirm the new tests fail.

### Phase 2 — Implementation
- [ ] Add `rate_limit_per_minute: int = 100` to `app/settings.py`.
- [ ] Create `app/rate_limit.py` with a dependency that runs `INCR` + `EXPIRE NX` on key `rl:{client_id}:{epoch_minute}`.
- [ ] Wire the dependency into every router except `/health`.

### Phase 3 — Verification
- [ ] Run the full suite.
- [ ] Document the new setting in `README.md`.

## 7. Agent Tasks
_None: the work is small and sequential._

## 8. Acceptance Criteria
- [ ] `pytest` passes with no failures.
- [ ] 101 requests in the same minute with one key return 100 × 200 and 1 × 429.
- [ ] The 429 response carries `Retry-After` between 1 and 60.
- [ ] `/health` returns 200 regardless of the counter.

## 9. Final Review
- [ ] Review every artifact produced (code, files, configs) against the Acceptance Criteria.
- [ ] Fix any divergence found and re-verify.
- [ ] Only then declare the plan complete.
