import json
from datetime import datetime
from pathlib import Path
from mcp.server.fastmcp import FastMCP

mcp = FastMCP("CodeReviewHub")
STORAGE_FILE = Path.home() / ".review_thread.json"

def _load_data():
    if not STORAGE_FILE.exists():
        return {"items": []}
    try:
        with open(STORAGE_FILE, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return {"items": []}

def _save_data(data):
    with open(STORAGE_FILE, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)

@mcp.tool()
def registrar_apontamento(autor: str, arquivo: str, linha_ou_trecho: str, observacao: str) -> str:
    """Registra uma nova observacao ou problema encontrado no codigo."""
    data = _load_data()
    item_id = len(data["items"]) + 1
    item = {
        "id": item_id,
        "autor": autor,
        "arquivo": arquivo,
        "trecho": linha_ou_trecho,
        "observacao": observacao,
        "timestamp": datetime.now().isoformat(),
        "respostas": []
    }
    data["items"].append(item)
    _save_data(data)
    return f"Apontamento #{item_id} registrado com sucesso por {autor}."

@mcp.tool()
def responder_apontamento(item_id: int, autor: str, resposta: str) -> str:
    """Responde a um apontamento existente, contra-argumentando ou concordando."""
    data = _load_data()
    for item in data["items"]:
        if item["id"] == item_id:
            item["respostas"].append({
                "autor": autor,
                "resposta": resposta,
                "timestamp": datetime.now().isoformat()
            })
            _save_data(data)
            return f"Resposta registrada no item #{item_id} por {autor}."
    return f"Item #{item_id} nao encontrado."

@mcp.tool()
def ler_discussao() -> str:
    """Retorna toda a thread de revisao com apontamentos e replicas."""
    data = _load_data()
    if not data["items"]:
        return "Nenhum apontamento registrado ate o momento."
    return json.dumps(data, indent=2, ensure_ascii=False)

@mcp.tool()
def limpar_discussao() -> str:
    """Limpa o historico de revisao para iniciar uma nova sessao."""
    _save_data({"items": []})
    return "Historico de revisao limpo."

if __name__ == "__main__":
    mcp.run()
