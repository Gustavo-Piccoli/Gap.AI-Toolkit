# Review Hub MCP (`CodeReviewHub`)

Servidor MCP (Model Context Protocol) leve, construído em Python com `FastMCP`, projetado para viabilizar sessões estruturadas de **Code Review multi-agente** (por exemplo, debates técnicos cruzados entre **Claude Code** e **Google Antigravity**).

## Propósito e Funcionamento

Em fluxos de desenvolvimento assistidos por múltiplos agentes de IA, um agente pode atuar como **Autor/Implementador** enquanto outro atua como **Revisor Crítico**. O `CodeReviewHub` funciona como um barramento compartilhado de revisão de código:

- Persiste apontamentos e réplicas localmente em `~/.review_thread.json` (`Path.home() / ".review_thread.json"`).
- Permite que diferentes agentes leiam a mesma thread de discussão, registrem novos apontamentos com localização exata (arquivo e linha/trecho) e contra-argumentem ou confirmem correções em cada item.
- Não depende de serviços externos nem de banco de dados — basta Python 3.10+ e o pacote `mcp`.

## Instalação de Dependências

```bash
pip install -r requirements.txt
```

## Tools Disponíveis

| Tool | Parâmetros | Descrição |
| :--- | :--- | :--- |
| `registrar_apontamento` | `autor: str`, `arquivo: str`, `linha_ou_trecho: str`, `observacao: str` | Registra uma nova observação, bug ou oportunidade de melhoria encontrada no código, atribuindo um ID sequencial (`#1`, `#2`, ...). |
| `responder_apontamento` | `item_id: int`, `autor: str`, `resposta: str` | Adiciona uma resposta a um apontamento existente (concordando, indicando a correção aplicada ou contra-argumentando tecnicamente). |
| `ler_discussao` | *(nenhum)* | Retorna toda a thread de revisão ativa em formato JSON identado, incluindo todos os apontamentos e suas respectivas réplicas. |
| `limpar_discussao` | *(nenhum)* | Limpa o histórico de revisão (`~/.review_thread.json`) para iniciar uma nova sessão limpa. |

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
