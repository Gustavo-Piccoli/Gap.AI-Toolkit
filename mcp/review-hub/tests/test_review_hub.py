from __future__ import annotations

import asyncio
import json
import multiprocessing
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import pytest
from mcp.client import Client

import review_hub as hub


@pytest.fixture
def storage(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Path:
    path = tmp_path / "thread.json"
    monkeypatch.setenv(hub.STORAGE_ENV_VAR, str(path))
    return path


def _call_tool(name: str, **arguments: object) -> str:
    """Chama a tool por um cliente MCP em memoria, passando pelo protocolo completo."""

    async def run() -> str:
        async with Client(hub.create_server()) as client:
            result = await client.call_tool(name, arguments)
        assert not result.is_error, result
        return result.content[0].text

    return asyncio.run(run())


# --- criacao e listagem -----------------------------------------------------
def test_storage_path_uses_env_var(storage: Path) -> None:
    assert hub.storage_path() == storage


def test_missing_file_is_empty_thread(storage: Path) -> None:
    assert hub.load_thread() == {"items": []}
    assert not storage.exists()


def test_add_item_persists_and_numbers_sequentially(storage: Path) -> None:
    first = hub.add_item("claude", "app.py", "L10", "Falta tratar None")
    second = hub.add_item("agy", "app.py", "L20", "Nome pouco claro")

    assert (first["id"], second["id"]) == (1, 2)
    on_disk = json.loads(storage.read_text(encoding="utf-8"))
    assert [i["observacao"] for i in on_disk["items"]] == ["Falta tratar None", "Nome pouco claro"]
    assert on_disk["items"][0]["respostas"] == []


def test_ids_use_max_plus_one_after_gaps(storage: Path) -> None:
    storage.write_text(json.dumps({"items": [{"id": 1, "respostas": []}, {"id": 7, "respostas": []}]}))
    assert hub.add_item("claude", "a.py", "L1", "x")["id"] == 8


def test_add_reply_and_unknown_item(storage: Path) -> None:
    item = hub.add_item("claude", "a.py", "L1", "x")
    hub.add_reply(item["id"], "agy", "Corrigido")

    thread = hub.load_thread()
    assert thread["items"][0]["respostas"][0]["resposta"] == "Corrigido"
    with pytest.raises(hub.ItemNotFoundError):
        hub.add_reply(99, "agy", "?")


def test_clear_thread(storage: Path) -> None:
    hub.add_item("claude", "a.py", "L1", "x")
    hub.clear_thread()
    assert hub.load_thread() == {"items": []}


def test_writes_leave_no_temp_files(storage: Path) -> None:
    for n in range(5):
        hub.add_item("claude", "a.py", f"L{n}", "x")
    leftovers = [p.name for p in storage.parent.iterdir() if p.suffix == ".tmp"]
    assert leftovers == []


# --- arquivo corrompido -----------------------------------------------------
def test_corrupted_json_raises_and_is_not_overwritten(storage: Path) -> None:
    storage.write_text('{"items": [ {"id": 1', encoding="utf-8")
    original = storage.read_text(encoding="utf-8")

    with pytest.raises(hub.StorageError, match="JSON corrompido"):
        hub.load_thread()
    with pytest.raises(hub.StorageError):
        hub.add_item("claude", "a.py", "L1", "x")

    assert storage.read_text(encoding="utf-8") == original


@pytest.mark.parametrize("payload", ["[]", '{"itens": []}', '{"items": [{"id": "1"}]}'])
def test_unexpected_shape_raises(storage: Path, payload: str) -> None:
    storage.write_text(payload, encoding="utf-8")
    with pytest.raises(hub.StorageError, match="Formato inesperado"):
        hub.load_thread()


# --- concorrencia -----------------------------------------------------------
def test_concurrent_threads_get_unique_ids(storage: Path) -> None:
    with ThreadPoolExecutor(max_workers=8) as pool:
        ids = list(pool.map(lambda n: hub.add_item("t", "a.py", f"L{n}", "x")["id"], range(40)))

    assert sorted(ids) == list(range(1, 41))
    assert len(hub.load_thread()["items"]) == 40


def _worker(path: str, count: int) -> None:
    for n in range(count):
        hub.add_item("proc", "a.py", f"L{n}", "x", path=Path(path))


def test_concurrent_processes_get_unique_ids(storage: Path) -> None:
    ctx = multiprocessing.get_context("spawn")
    procs = [ctx.Process(target=_worker, args=(str(storage), 10)) for _ in range(4)]
    for p in procs:
        p.start()
    for p in procs:
        p.join(timeout=60)
        assert p.exitcode == 0

    ids = [item["id"] for item in hub.load_thread(storage)["items"]]
    assert sorted(ids) == list(range(1, 41))


# --- camada MCP -------------------------------------------------------------
def test_mcp_tools_round_trip(storage: Path) -> None:
    assert _call_tool("ler_discussao") == "Nenhum apontamento registrado ate o momento."
    assert "#1" in _call_tool(
        "registrar_apontamento", autor="claude", arquivo="a.py", linha_ou_trecho="L1", observacao="x"
    )
    assert "#1" in _call_tool("responder_apontamento", item_id=1, autor="agy", resposta="ok")
    assert "nao encontrado" in _call_tool("responder_apontamento", item_id=5, autor="agy", resposta="?")
    assert json.loads(_call_tool("ler_discussao"))["items"][0]["respostas"][0]["autor"] == "agy"
    assert _call_tool("limpar_discussao") == "Historico de revisao limpo."


# --- documentacao -----------------------------------------------------------
REPO_ROOT = Path(__file__).resolve().parents[3]


def test_documented_schema_matches_written_items(storage: Path) -> None:
    schema = json.loads((REPO_ROOT / "docs" / "review-hub.schema.json").read_text(encoding="utf-8"))
    item = hub.add_item("claude", "a.py", "L1", "x")
    reply = hub.add_reply(item["id"], "agy", "ok")

    assert set(item) == set(schema["$defs"]["item"]["required"])
    assert set(reply) == set(schema["$defs"]["reply"]["required"])


def test_example_thread_is_loadable() -> None:
    example = REPO_ROOT / "examples" / "todo-api-rate-limit" / "review-thread.json"
    thread = hub.load_thread(example)
    assert [i["id"] for i in thread["items"]] == [1, 2]
