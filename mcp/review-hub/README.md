# Review Hub MCP (`CodeReviewHub`)

Servidor MCP (Model Context Protocol) leve, construído em Python com `FastMCP`, projetado para viabilizar sessões estruturadas de **Code Review multi-agente** (por exemplo, debates técnicos cruzados entre **Claude Code** e **Google Antigravity**).

## Propósito e Funcionamento

Em fluxos com mais de um agente de IA, um agente atua como **Autor/Implementador** e outro como **Revisor Crítico**. O `CodeReviewHub` é o barramento compartilhado entre eles:

- Persiste apontamentos e réplicas num arquivo JSON local: `~/.review_thread.json` por padrão, ou o caminho da variável de ambiente **`REVIEW_HUB_STORAGE`**.
- Vários agentes podem ler e escrever a mesma thread ao mesmo tempo: toda escrita roda sob **lock de arquivo** entre processos e é **atômica** (arquivo temporário + `fsync` + `os.replace`).
- IDs são alocados por `max(id) + 1`, então continuam únicos mesmo depois de edições manuais no arquivo.
- Um JSON corrompido gera **erro explícito** com o caminho do arquivo e nunca é sobrescrito em silêncio.
- Não depende de serviços externos nem de banco de dados: só Python 3.10+ e o pacote `mcp` (fixado em `1.30.0`; a linha 2.x renomeou o `FastMCP`).

O formato do arquivo está documentado em [`docs/review-hub-format.md`](../../docs/review-hub-format.md), com um [JSON Schema](../../docs/review-hub.schema.json) e um [exemplo](../../examples/todo-api-rate-limit/review-thread.json).

## Instalação

```bash
pip install -r requirements.txt          # só para rodar o servidor
pip install -e ".[dev]"                  # para desenvolver: inclui pytest e ruff
```

## Testes

```bash
python -m pytest -v
ruff check . && ruff format --check .
```

A suíte cobre criação e listagem, numeração `max(id)+1`, respostas, limpeza, JSON corrompido ou com formato inesperado, escrita concorrente (threads e processos) e uma ida e volta pelas tools MCP. Os testes de concorrência falham se o lock for removido.

## Tools Disponíveis

| Tool | Parâmetros | Descrição |
| :--- | :--- | :--- |
| `registrar_apontamento` | `autor: str`, `arquivo: str`, `linha_ou_trecho: str`, `observacao: str` | Registra uma nova observação, bug ou oportunidade de melhoria encontrada no código e devolve o ID atribuído (`#1`, `#2`, ...). |
| `responder_apontamento` | `item_id: int`, `autor: str`, `resposta: str` | Adiciona uma resposta a um apontamento existente (concordando, indicando a correção aplicada ou contra-argumentando). |
| `ler_discussao` | *(nenhum)* | Retorna toda a thread ativa em JSON indentado, com apontamentos e réplicas. |
| `limpar_discussao` | *(nenhum)* | Limpa o histórico de revisão para iniciar uma nova sessão. |

Para usar outro arquivo por cliente, defina `REVIEW_HUB_STORAGE` no bloco `env` da configuração do servidor MCP.

## Configuração nos Agentes

O script `scripts/Setup-Environment.ps1` deste repositório configura automaticamente o caminho do `review-hub` tanto no Claude Code quanto no Google Antigravity. Caso deseje registrar manualmente:

### 1. Claude Code (`~/.claude.json`)

Adicione ou atualize a entrada `review-hub` dentro do objeto `mcpServers` na raiz de `~/.claude.json`:

```json
{
  "mcpServers": {
    "review-hub": {
      "command": "<PYTHON_EXE>",
      "args": [
        "<TOOLKIT_ROOT>/mcp/review-hub/review_hub.py"
      ]
    }
  }
}
```

Também é possível registrá-lo via CLI do Claude Code:

```bash
claude mcp add --scope user review-hub "<PYTHON_EXE>" "<TOOLKIT_ROOT>/mcp/review-hub/review_hub.py"
```

### 2. Google Antigravity (`~/.gemini/config/mcp_config.json`)

Adicione a entrada `review-hub` em `mcpServers` no arquivo `~/.gemini/config/mcp_config.json`:

```json
{
  "mcpServers": {
    "review-hub": {
      "command": "<PYTHON_EXE>",
      "args": [
        "<TOOLKIT_ROOT>/mcp/review-hub/review_hub.py"
      ],
      "disabled": false
    }
  }
}
```
