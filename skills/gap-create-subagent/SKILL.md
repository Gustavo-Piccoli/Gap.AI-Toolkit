---
name: gap-create-subagent
description: Ajuda a refinar instruções soltas do usuário até virarem um subagente global bem definido (nome "agent-XXXXX") mais o slash command correspondente. Use quando o usuário pedir para criar, desenhar ou registrar um novo subagente/comando personalizado que precise rodar em contexto isolado ou com tools/model restritos.
---

# gap-create-subagent

Você ajuda o usuário a transformar uma ideia solta de subagente em um subagente global bem escrito, e cria também o slash command correspondente. Este é um fluxo **interativo** — não escreva nenhum arquivo sem antes mostrar um rascunho e obter aprovação explícita do usuário.

Diferença em relação a `gap-create-skill`: um subagente roda em contexto isolado (via ferramenta `Agent` no Claude Code / `invoke_subagent` no Antigravity), tem seu próprio conjunto restrito de `tools` e, opcionalmente, um `model` próprio — útil quando o fluxo se beneficia de isolamento de contexto ou de least-privilege. Se o pedido do usuário não precisar de nada disso (é só um fluxo de passos que roda na sessão principal), avise que uma skill (`gap-create-skill`) pode ser mais simples e pergunte como ele prefere seguir.

> **Nota sobre equivalência Multi-IA (Claude Code vs. Google Antigravity):**
> - No **Claude Code**, subagentes globais persistentes são definidos como arquivos Markdown em `~/.claude/agents/agent-XXXXX.md` acompanhados de um comando em `~/.claude/commands/agent-XXXXX.md`, e invocados via tool `Agent`.
> - No **Google Antigravity (AGY)**, subagentes de sessão podem ser definidos dinamicamente via tool `define_subagent` e invocados via `invoke_subagent`, enquanto customizações e agentes persistentes ficam em `.agents/` (ou `~/.agents/skills/`). Mantenha o fluxo completo de `~/.claude/agents/` + `~/.claude/commands/` abaixo quando estiver gerando artefatos para o Claude Code, ou adapte para `.agents/` / `define_subagent` caso o usuário peça especificamente apenas para o Antigravity.

## 1. Entender o pedido
Leia a descrição inicial que o usuário deu do subagente desejado (o que ele deve fazer, quando deve ser chamado). Se algo estiver vago, você vai refinar isso nas próximas etapas — não invente comportamento.

## 2. Levantar convenções existentes
Rode em paralelo: `Glob ~/.claude/agents/*.md` e `Glob ~/.claude/commands/*.md` (ou verifique `.agents/` quando aplicável). Leia pelo menos um subagente global existente para manter consistência de estilo de frontmatter e de tom das instruções (português, seções curtas, passos numerados).

## 3. Definir o nome (`agent-XXXXX`)
Todo subagente criado por você segue o padrão de nome `agent-XXXXX`, em kebab-case.
- Pergunte ao usuário (via `AskUserQuestion` no Claude Code / `ask_question` no Antigravity) se ele quer informar o `XXXXX` ou prefere que você sugira. Se ele pedir sugestão, proponha 2–3 opções de slug curto e descritivo baseado no propósito do subagente.
- Depois de ter um candidato, confira colisão: `Glob ~/.claude/agents/agent-<slug>.md` e `Glob ~/.claude/commands/agent-<slug>.md`. Se já existir (subagente ou comando), **não sobrescreva**: avise o usuário e peça um nome diferente.
- O slash command usa o **mesmo nome completo do subagente**, incluindo o prefixo: subagente `agent-XXXXX` → comando `/agent-XXXXX`.

## 4. Refinar as instruções
Use `AskUserQuestion` (Claude Code) / `ask_question` (Antigravity) para fechar os pontos que o usuário não deixou claros. Cubra pelo menos:
- **Gatilho/objetivo**: em que situação exata esse subagente deve ser usado? (isso vira o campo `description`, que é o que a IA usa para decidir quando invocá-lo automaticamente — precisa ser específico e orientado a ação, não genérico).
- **Passos**: qual o fluxo que o subagente deve seguir, em ordem?
- **Limites**: o que ele explicitamente NÃO deve fazer (ex.: não sobrescrever sem confirmar, não usar `--force`, não commitar segredos)?
- **Entrada esperada**: que informação/contexto o subagente normalmente vai receber quando for chamado?
- **Saída esperada**: o que ele deve reportar ao final (resumo curto, arquivo criado, confirmação de uma ação)?
- **Ferramentas (`tools`)**: sugira o menor conjunto necessário com base na tarefa (ex.: `Bash` para comandos de shell/git, `Read`/`Write`/`Edit` para editar arquivos, `Grep`/`Glob` para busca, `WebFetch`/`WebSearch` para pesquisa, `AskUserQuestion` / `ask_question` só se o subagente também precisar interagir com o usuário) e confirme com o usuário. Prefira o mínimo privilégio — não dê `Bash` genérico se o subagente só precisa editar arquivos.
- **Modelo (`model`)**: pergunte se o usuário quer forçar um modelo (`sonnet`/`opus`/`haiku` no Claude Code, ou `inherit`/`flash_lite`/`flash`/`pro` no Antigravity) ou herdar o modelo do agente pai (recomendado como padrão — nesse caso, omita o campo `model` no frontmatter).
- **Interatividade**: se o subagente usa `AskUserQuestion`, lembre o usuário que no Claude Code a invocação precisa rodar em foreground (`run_in_background: false`) para a interação funcionar — isso deve constar no comando gerado no passo 5.

Antes de finalizar, verifique rapidamente se o propósito do novo subagente não se sobrepõe fortemente a um subagente ou skill global já existente (pelas convenções levantadas no passo 2); se sobrepuser, avise o usuário e pergunte se prefere estender o existente em vez de criar um novo.

## 5. Rascunhar e confirmar
Monte o rascunho completo — **sempre os dois arquivos juntos, nunca só um**:
- Arquivo do subagente (`~/.claude/agents/agent-XXXXX.md`): frontmatter (`name`, `description`, `tools`, `model` se aplicável) + corpo de instruções em português, passos numerados, autocontido (o subagente roda sem memória desta conversa, então nada de "como combinamos acima").
- Arquivo do comando (`~/.claude/commands/agent-XXXXX.md`): frontmatter com `description` curta + corpo que instrui a invocar o subagente `agent-XXXXX` via `Agent` tool (`subagent_type: agent-XXXXX` no Claude Code, ou `invoke_subagent` no Antigravity) e repassar o resultado ao usuário. Se o subagente precisar interagir com o usuário (tem `AskUserQuestion` nas tools), inclua a instrução de invocar com `run_in_background: false`.

Mostre os dois rascunhos completos ao usuário e pergunte se aprova ou quer ajustar algo. Só escreva os arquivos depois de aprovação explícita.

## 6. Criar os arquivos
Após aprovação, escreva os dois arquivos com `Write` (`write_file`). Confirme ao usuário que ambos foram criados, com os caminhos completos, e avise que pode ser necessário reiniciar a sessão da CLI para o `/agent-XXXXX` aparecer no autocomplete.
