"""CodeReviewHub: servidor MCP para threads estruturadas de code review entre agentes.

A thread fica num arquivo JSON local. O caminho vem da variavel de ambiente
``REVIEW_HUB_STORAGE`` (padrao: ``~/.review_thread.json``). Toda operacao de
leitura-modificacao-escrita roda sob um lock de arquivo e grava de forma atomica
(arquivo temporario + ``os.replace``), entao varios agentes podem usar o mesmo
arquivo ao mesmo tempo. Um arquivo corrompido gera erro explicito e nunca e
sobrescrito em silencio.
"""

from __future__ import annotations

import json
import os
import tempfile
import time
from collections.abc import Iterator
from contextlib import contextmanager, suppress
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, TypedDict

STORAGE_ENV_VAR = "REVIEW_HUB_STORAGE"
DEFAULT_STORAGE_FILE = Path.home() / ".review_thread.json"
LOCK_TIMEOUT_SECONDS = 10.0


class Reply(TypedDict):
    autor: str
    resposta: str
    timestamp: str


class Item(TypedDict):
    id: int
    autor: str
    arquivo: str
    trecho: str
    observacao: str
    timestamp: str
    respostas: list[Reply]


class Thread(TypedDict):
    items: list[Item]


class StorageError(RuntimeError):
    """Arquivo da thread ilegivel, corrompido ou com formato inesperado."""


class ItemNotFoundError(LookupError):
    """O apontamento pedido nao existe na thread."""


def storage_path() -> Path:
    """Caminho do arquivo da thread, lido a cada chamada (permite trocar via ambiente)."""
    configured = os.environ.get(STORAGE_ENV_VAR, "").strip()
    return Path(configured).expanduser() if configured else DEFAULT_STORAGE_FILE


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _empty_thread() -> Thread:
    return {"items": []}


# ---------------------------------------------------------------------------
# Lock de arquivo (stdlib, Windows e POSIX)
# ---------------------------------------------------------------------------
@contextmanager
def _file_lock(path: Path, timeout: float = LOCK_TIMEOUT_SECONDS) -> Iterator[None]:
    """Lock exclusivo em ``<arquivo>.lock``, entre processos."""
    lock_path = path.with_name(path.name + ".lock")
    lock_path.parent.mkdir(parents=True, exist_ok=True)
    with open(lock_path, "a+b") as handle:
        deadline = time.monotonic() + timeout
        if os.name == "nt":
            import msvcrt

            while True:
                try:
                    handle.seek(0)
                    msvcrt.locking(handle.fileno(), msvcrt.LK_NBLCK, 1)
                    break
                except OSError:
                    if time.monotonic() >= deadline:
                        raise StorageError(f"Timeout ao aguardar o lock de {path}") from None
                    time.sleep(0.02)
            try:
                yield
            finally:
                handle.seek(0)
                msvcrt.locking(handle.fileno(), msvcrt.LK_UNLCK, 1)
        else:
            import fcntl

            while True:
                try:
                    fcntl.flock(handle.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
                    break
                except BlockingIOError:
                    if time.monotonic() >= deadline:
                        raise StorageError(f"Timeout ao aguardar o lock de {path}") from None
                    time.sleep(0.02)
            try:
                yield
            finally:
                fcntl.flock(handle.fileno(), fcntl.LOCK_UN)


# ---------------------------------------------------------------------------
# Leitura e escrita
# ---------------------------------------------------------------------------
def _validate(data: Any, path: Path) -> Thread:
    if not isinstance(data, dict) or not isinstance(data.get("items"), list):
        raise StorageError(f"Formato inesperado em {path}: esperado um objeto com a lista 'items'.")
    for item in data["items"]:
        if not isinstance(item, dict) or not isinstance(item.get("id"), int):
            raise StorageError(f"Formato inesperado em {path}: todo item precisa de um 'id' inteiro.")
    return data  # type: ignore[return-value]


def load_thread(path: Path | None = None) -> Thread:
    """Le a thread. Arquivo ausente equivale a thread vazia; arquivo invalido gera StorageError."""
    path = path or storage_path()
    if not path.exists():
        return _empty_thread()
    try:
        raw = path.read_text(encoding="utf-8")
    except OSError as exc:
        raise StorageError(f"Nao foi possivel ler {path}: {exc}") from exc
    if not raw.strip():
        return _empty_thread()
    try:
        data = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise StorageError(
            f"JSON corrompido em {path} (linha {exc.lineno}, coluna {exc.colno}). "
            "O arquivo nao foi alterado: corrija-o ou mova-o antes de continuar."
        ) from exc
    return _validate(data, path)


def _write_atomic(path: Path, data: Thread) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp_name = tempfile.mkstemp(dir=path.parent, prefix=f".{path.name}.", suffix=".tmp")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as tmp:
            json.dump(data, tmp, indent=2, ensure_ascii=False)
            tmp.write("\n")
            tmp.flush()
            os.fsync(tmp.fileno())
        os.replace(tmp_name, path)
    except BaseException:
        with suppress(FileNotFoundError):
            os.unlink(tmp_name)
        raise


@contextmanager
def _transaction(path: Path | None = None) -> Iterator[Thread]:
    """Le a thread sob lock e, se o bloco terminar sem erro, grava o resultado atomicamente."""
    path = path or storage_path()
    with _file_lock(path):
        data = load_thread(path)
        yield data
        _write_atomic(path, data)


def _next_id(items: list[Item]) -> int:
    return max((item["id"] for item in items), default=0) + 1


# ---------------------------------------------------------------------------
# Operacoes (independentes do MCP, usadas pelas tools e pelos testes)
# ---------------------------------------------------------------------------
def add_item(autor: str, arquivo: str, trecho: str, observacao: str, path: Path | None = None) -> Item:
    with _transaction(path) as data:
        item: Item = {
            "id": _next_id(data["items"]),
            "autor": autor,
            "arquivo": arquivo,
            "trecho": trecho,
            "observacao": observacao,
            "timestamp": _now(),
            "respostas": [],
        }
        data["items"].append(item)
    return item


def add_reply(item_id: int, autor: str, resposta: str, path: Path | None = None) -> Reply:
    with _transaction(path) as data:
        for item in data["items"]:
            if item["id"] == item_id:
                reply: Reply = {"autor": autor, "resposta": resposta, "timestamp": _now()}
                item.setdefault("respostas", []).append(reply)
                return reply
        raise ItemNotFoundError(item_id)


def clear_thread(path: Path | None = None) -> None:
    path = path or storage_path()
    with _file_lock(path):
        _write_atomic(path, _empty_thread())


# ---------------------------------------------------------------------------
# Servidor MCP
# ---------------------------------------------------------------------------
def create_server() -> Any:
    from mcp.server.mcpserver import MCPServer

    server = MCPServer("CodeReviewHub")

    @server.tool()
    def registrar_apontamento(autor: str, arquivo: str, linha_ou_trecho: str, observacao: str) -> str:
        """Registra uma nova observacao ou problema encontrado no codigo."""
        item = add_item(autor, arquivo, linha_ou_trecho, observacao)
        return f"Apontamento #{item['id']} registrado com sucesso por {autor}."

    @server.tool()
    def responder_apontamento(item_id: int, autor: str, resposta: str) -> str:
        """Responde a um apontamento existente, contra-argumentando ou concordando."""
        try:
            add_reply(item_id, autor, resposta)
        except ItemNotFoundError:
            return f"Item #{item_id} nao encontrado."
        return f"Resposta registrada no item #{item_id} por {autor}."

    @server.tool()
    def ler_discussao() -> str:
        """Retorna toda a thread de revisao com apontamentos e replicas."""
        data = load_thread()
        if not data["items"]:
            return "Nenhum apontamento registrado ate o momento."
        return json.dumps(data, indent=2, ensure_ascii=False)

    @server.tool()
    def limpar_discussao() -> str:
        """Limpa o historico de revisao para iniciar uma nova sessao."""
        clear_thread()
        return "Historico de revisao limpo."

    return server


def main() -> None:
    create_server().run()


if __name__ == "__main__":
    main()
