# CodeReviewHub: storage format

The `review-hub` MCP server keeps one review thread in a single UTF-8 JSON file. This page documents that file so other tools (or a human) can read it, and so changes to it are deliberate.

Machine-readable version: [`review-hub.schema.json`](./review-hub.schema.json) (JSON Schema 2020-12). Real-looking sample: [`examples/todo-api-rate-limit/review-thread.json`](../examples/todo-api-rate-limit/review-thread.json).

## Location

| Source | Path |
| --- | --- |
| `REVIEW_HUB_STORAGE` environment variable (`~` is expanded) | any path you choose |
| default | `~/.review_thread.json` |

The variable is read on every call, so it can be set per MCP client in its `env` block. Next to the file the server creates `<file>.lock`, used only for locking; it can be deleted safely when no agent is running.

## Structure

```jsonc
{
  "items": [                       // findings, in creation order
    {
      "id": 1,                     // integer ≥ 1, unique; next id = max(id) + 1
      "autor": "reviewer-agent",   // free text: who registered the finding
      "arquivo": "src/app.py",     // file the finding refers to
      "trecho": "L10-L14",         // line, range or code excerpt (tool argument: linha_ou_trecho)
      "observacao": "…",           // the finding itself
      "timestamp": "2026-11-21T14:02:11.418203+00:00", // ISO 8601, UTC
      "respostas": [               // replies, in order
        {
          "autor": "implementer-agent",
          "resposta": "…",
          "timestamp": "2026-11-21T14:05:47.902115+00:00"
        }
      ]
    }
  ]
}
```

Field names are in Portuguese because they are part of the tool contract the agents already use.

## Tool ↔ file mapping

| Tool | Effect on the file |
| --- | --- |
| `registrar_apontamento(autor, arquivo, linha_ou_trecho, observacao)` | appends an item with `id = max(id) + 1` and an empty `respostas` |
| `responder_apontamento(item_id, autor, resposta)` | appends a reply to the item; returns "not found" without writing if the id does not exist |
| `ler_discussao()` | read only; returns the whole file as JSON |
| `limpar_discussao()` | replaces the content with `{"items": []}` |

## Guarantees

- **Locking:** every read-modify-write runs under an exclusive lock on `<file>.lock` (`fcntl.flock` on POSIX, `msvcrt.locking` on Windows), so several agents can write at the same time without losing items or repeating ids. Waiting for the lock times out after 10 s with an error.
- **Atomic writes:** the new content goes to a temporary file in the same folder, is flushed with `fsync`, then replaces the original with `os.replace`. A crash leaves either the old or the new file, never a half-written one.
- **No silent resets:** an empty or missing file is an empty thread. Invalid JSON, or JSON that is not an object with an `items` list whose items have integer `id`s, raises an error naming the file, and the file is left untouched.

## Compatibility

Files written by the first version of the server (local-time timestamps without offset, `id = len + 1`) are read as they are. New timestamps are written in UTC with an offset.
