---
name: gap-create-skill
description: Ajuda a refinar instruções soltas do usuário até virarem uma skill global bem definida (nome "gap-XXXXX"). Use quando o usuário pedir para criar, desenhar ou registrar uma nova skill/comando personalizado para uso pessoal.
---

# gap-create-skill

Você ajuda o usuário a transformar uma ideia solta de skill em uma skill global bem escrita. Este é um fluxo **interativo** — não escreva nenhum arquivo sem antes mostrar um rascunho e obter aprovação explícita do usuário.

## 1. Entender o pedido
Leia a descrição inicial que o usuário deu da skill desejada (o que ela deve fazer, quando deve ser chamada). Se algo estiver vago, você vai refinar isso nas próximas etapas — não invente comportamento.

## 2. Levantar convenções existentes
Liste as skills globais já existentes do usuário (na pasta `skills/*/SKILL.md` do repositório `Gap.AI-Toolkit`, ou nos diretórios globais `~/.claude/skills/*/SKILL.md` no Claude Code / `~/.agents/skills/*/SKILL.md` no Antigravity). Leia pelo menos uma skill `gap-*` existente (ex.: `gap-commit`, `gap-pr`, se existirem) para manter consistência de estilo de frontmatter e de tom das instruções (português, seções curtas, passos numerados).

## 3. Definir o nome (`gap-XXXXX`)
Toda skill criada por você segue o padrão de nome `gap-XXXXX`, em kebab-case.
- Pergunte ao usuário (usando `AskUserQuestion` no Claude Code / `ask_question` no Antigravity, ou diretamente na conversa) se ele quer informar o `XXXXX` ou prefere que você sugira. Se ele pedir sugestão, proponha 2–3 opções de slug curto e descritivo baseado no propósito da skill.
- Depois de ter um candidato, confira colisão com skills já existentes com o mesmo nome. Se já existir, **não sobrescreva**: avise o usuário e peça um nome diferente.
- A invocação da skill usa o **mesmo nome completo**, incluindo o prefixo: skill `gap-XXXXX` é referenciada como `gap-XXXXX` (ex.: em slash command, se o ambiente suportar: `/gap-XXXXX`).

## 4. Refinar as instruções
Faça perguntas (via `AskUserQuestion` no Claude Code / `ask_question` no Antigravity) para fechar os pontos que o usuário não deixou claros. Cubra pelo menos:
- **Gatilho/objetivo**: em que situação exata essa skill deve ser usada? (isso vira o campo `description`, que é o que o Claude Code e o Antigravity usam para decidir quando consultar a skill automaticamente — precisa ser específico e orientado a ação, não genérico, e pode ser um pouco "insistente" para evitar subacionamento).
- **Passos**: qual o fluxo que a skill deve seguir, em ordem?
- **Limites**: o que ela explicitamente NÃO deve fazer (ex.: não sobrescrever sem confirmar, não usar `--force`, não commitar segredos)?
- **Entrada esperada**: que informação/contexto a skill normalmente vai receber quando for usada?
- **Saída esperada**: o que ela deve reportar ao final (resumo curto, arquivo criado, confirmação de uma ação)?
- **Recursos adicionais**: a skill precisa de scripts, templates ou arquivos de referência além do SKILL.md? Se sim, planeje a estrutura de pastas (`scripts/`, `references/`, `assets/`).

Antes de finalizar, verifique rapidamente se o propósito da nova skill não se sobrepõe fortemente a uma skill global já existente (pelas descrições lidas no passo 2); se sobrepuser, avise o usuário e pergunte se prefere estender a skill existente em vez de criar uma nova.

Se o pedido do usuário for na verdade para criar um **subagente** (algo que precisa de tools restritas, executa em contexto isolado via tool `Agent` no Claude Code / `invoke_subagent` no Antigravity, ou vem acompanhado de slash command dedicado com controle de `tools`/`model`), avise que o caso pode se encaixar melhor na skill `gap-create-subagent` e pergunte como ele prefere seguir.

## 5. Rascunhar e confirmar
Monte o rascunho completo do arquivo da skill (`gap-XXXXX/SKILL.md`): frontmatter (`name`, `description`) + corpo de instruções em português, passos numerados, autocontido (a skill roda sem memória desta conversa, então nada de "como combinamos acima").

Mostre o rascunho completo ao usuário e pergunte se aprova ou quer ajustar algo. Só escreva o arquivo depois de aprovação explícita.

## 6. Criar os arquivos
Após aprovação, crie a skill na pasta `skills/gap-XXXXX/SKILL.md` do repositório `Gap.AI-Toolkit` (ou em `~/.claude/skills/gap-XXXXX/SKILL.md` / `~/.agents/skills/gap-XXXXX/SKILL.md`, que são linkados via Junction/manifesto para o Claude Code e o Antigravity). Confirme ao usuário que foi criada, com o caminho completo, e avise se for necessário atualizar os links/manifesto ou reiniciar a sessão para a skill `gap-XXXXX` ficar disponível.
