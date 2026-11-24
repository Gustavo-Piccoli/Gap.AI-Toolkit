# Diretrizes Universais para Agentes de IA (AGENTS.md)

Este documento é a **Fonte Única da Verdade** para o comportamento, governança arquitetural, orquestração multi-agente e higiene de engenharia em qualquer ferramenta ou assistente de IA (Claude Code, Google Antigravity, Cursor, Codex e equivalentes).

---

## 1. Inversão de Controle e Decisões de Arquitetura

### 1.1 Explicar Antes de Modificar
Antes de editar qualquer arquivo (código, estrutura, configuração ou documentação), apresente de forma objetiva:
1. **O quê** será alterado (arquivo, classe, método ou seção).
2. **Por quê** a alteração é necessária (motivação técnica e problema que resolve).
3. Aguarde **aceite explícito** do usuário antes de aplicar a modificação (salvo durante a execução autorizada de um plano já fechado e aprovado).

### 1.2 Proibição de Suposições em Cenários Ambíguos
Nunca presuma requisitos, contratos de interface, regras de negócio ou convenções não documentadas:
- Diante de qualquer lacuna ou ambiguidade que não possa ser resolvida pela leitura direta do código ou da documentação do projeto, **pare e pergunte antes de agir**.
- É sempre preferível fazer uma pergunta direta e objetiva a implementar comportamento baseado em inferências não verificadas.

### 1.3 Parcelamento de Decisões Arquiteturais
Ao desenhar ou implementar funcionalidades não-triviais:
- **Não** projete toda a arquitetura em silêncio para apresentá-la pronta de uma só vez.
- **Parcele as decisões de mecanismo** (protocolo, formato de contrato/estrutura de dados, limites/thresholds, intervalos, alocação de responsabilidades entre camadas) em etapas pequenas e sequenciais, obtendo aprovação explícita em cada passo antes de avançar para o próximo.

### 1.4 Apresentação de Opções e Trade-offs Antes de Recomendar
Sempre que a tarefa envolver discutir, avaliar ou escolher abordagens para um problema aberto (inclusive quando o levantamento for delegado a um subagente):
- Apresente primeiro as **opções candidatas lado a lado** (preferencialmente em tabela comparativa), detalhando o funcionamento, os prós, os contras e os impactos de manutenção de cada alternativa.
- Só emita uma recomendação sintetizada **após** expor claramente as opções, convidando o usuário a ponderar e decidir.
- Ao delegar análise de alternativas a um subagente, instrua-o a **retornar todas as opções com seus trade-offs**, nunca apenas a opção vencedora escolhida unilateralmente.

### 1.5 Tratamento de Timeout em Perguntas Interativas
Quando uma pergunta feita ao usuário via ferramenta interativa sofrer timeout ou cancelamento sem resposta:
- **Repergunte** (pelo menos uma vez) em vez de assumir uma decisão silenciosa imediatamente.
- Caso o timeout persista em um fluxo de execução autônoma, adote o caminho mais conservador e estritamente aderente ao plano aprovado, registre a decisão em aberto e destaque-a com visibilidade no resumo final da tarefa.

### 1.6 Preferência por Design Enxuto e Manutenibilidade de Longo Prazo
Na avaliação entre alternativas técnicas:
- Priorize a solução que mantenha o projeto **enxuto** e exija **menos refatoração futura**.
- Rejeite camadas de compatibilidade desnecessárias, fontes de verdade duplicadas ou código que exista apenas para contornar sintomas de implementações legadas.
- Recomende a solução estruturalmente limpa mesmo quando o custo de implementação imediato for ligeiramente maior.

---

## 2. Orquestração Multi-Agente e Gestão de Contexto

### 2.1 Hierarquia Controlada (Árvore Rasa)
- Mantenha a hierarquia de agentes rasa e previsível: **Coordenador → Agente Executor** (com no máximo 1 nível adicional de subagentes auxiliares rápidos quando estritamente necessário para eficiência).
- Subagentes de segundo nível são **terminantemente proibidos** de instanciar novos subagentes.
- Agentes **revisores** são sempre despachados diretamente pelo Coordenador — um agente implementador nunca despacha o próprio revisor.

### 2.2 Ciclo de Vida de Sessões e Subagentes
- Só crie agentes separados e endereçáveis se o usuário precisar conversar diretamente com eles; todo o restante deve operar como subagente efêmero orientando-se por tarefa.
- **Encerre subagentes imediatamente** (`TaskStop` / `kill`) assim que entregarem seu relatório final e confira na listagem de agentes que nenhuma instância permaneceu ociosa retendo contexto acumulado.
- Ao concluir uma fase de trabalho, prefira encerrar o agente e iniciar a fase seguinte com um agente novo e contexto enxuto. O handoff entre fases deve ser feito por **artefato escrito em disco**, registrando não apenas a decisão tomada, mas também as **alternativas rejeitadas e o motivo da rejeição**.

### 2.3 Nomenclatura Padronizada de Agentes
Todo agente despachado pelo coordenador deve receber um identificador explícito no formato `<papel>-<tarefa>`, utilizando exclusivamente letras, dígitos, `_` e `-` (substituindo pontos por hífens, até 64 caracteres):
- Exemplos: `explorador-autenticacao`, `implementacao-5-1b`, `revisao-seguranca`, `correcao-1-11b-2`, `levantamento-fase-4`.
- Rodadas adicionais executadas por uma nova instância de agente para a mesma tarefa recebem sufixo numérico incremental (`-2`, `-3`).

### 2.4 Compressão de Contexto e Delegação de Leitura
- Tarefas de alta leitura e baixa saída (varrer repositórios, mapear dependências, auditar chamadas, investigar documentação extensa) devem ser **delegadas a subagentes**, nunca executadas inline no contexto do coordenador.
- O subagente deve retornar um resumo denso de no máximo **20 a 30 linhas**, ancorado em referências precisas (`arquivo:linha`, nome exato de símbolo, SHA de commit), **sem colar blocos extensos de código**. Se for indispensável produzir trechos de código ou relatórios longos, o subagente deve gravá-los em arquivo (ex.: `.orq/`) e retornar apenas o caminho.
- Se um subagente encontrar uma ambiguidade de negócio ou arquitetura que não lhe cabe decidir, deve interromper a execução imediatamente e retornar `BLOQUEADO: <pergunta objetiva>`.

### 2.5 Debate Adversarial entre Agentes
- **Proibido debater via troca direta de mensagens** entre agentes (o histórico cruzado cresce quadraticamente em consumo de tokens e induz ancoragem prematura).
- Todo debate técnico ou revisão adversarial deve ocorrer por meio de:
  1. **Arquivo dedicado em disco** (`.orq/debate-<tema>.md`), onde cada rodada de crítica utiliza um subagente revisor novo e descartável; ou
  2. **Servidor MCP `review-hub`**, utilizando as ferramentas estruturadas `registrar_apontamento`, `responder_apontamento`, `ler_discussao` e `limpar_discussao`.
- **Limite máximo de 3 rodadas:** pontos que não convergirem em até 3 rodadas **não** devem ser forçados a um consenso artificial por insistência. Eles devem ser escalados ao usuário com as posições divergentes e seus argumentos claramente listados para decisão humana.

### 2.6 Gestão de Modelos, Créditos e Quota Externa (`agy`)
- **Alocação por complexidade cognitiva:**
  - Utilize modelos de fronteira / alto raciocínio (ex.: Claude Opus, Gemini Pro High) para arquitetura, criação de planos, desambiguação de requisitos e revisão adversarial.
  - Utilize modelos ágeis e econômicos (ex.: Claude Sonnet, Gemini Flash) para execução de planos já fechados, subagentes de exploração e tarefas bem delimitadas. Ao finalizar um plano com modelo pesado, lembre o usuário da opção de alternar para o modelo ágil antes de iniciar a implementação.
- **Refatorações mecânicas em massa:** quando uma etapa envolver apenas movimentação ou renomeação mecânica de muitos arquivos e namespaces, ofereça ao usuário a opção de executá-la diretamente pela IDE antes de gastar tokens com edições repetitivas.
- **Uso de quota externa via Antigravity CLI (`agy`):**
  - Leituras pesadas de código com resposta curta podem ser delegadas ao `agy` para preservar a quota principal para decisão e escrita.
  - **Sempre redirecione a saída para arquivo:** `agy -p "..." > .orq/relatorio-<nome>.md`. Nunca permita que a saída bruta do CLI caia diretamente no contexto do agente chamador.
  - Padrão recomendado: um subagente invoca o `agy`, lê o relatório gerado em `.orq/` e devolve até 20 linhas sintetizadas ao coordenador. O `agy` atua estritamente como leitor e analista — não decide arquitetura nem edita código.

---

## 3. Grafos de Conhecimento (Graphify First)

No início de cada sessão (antes de explorar ou modificar qualquer repositório), verifique se existe o arquivo `graphify-out/graph.json` (ou `.claude/graphify-out/graph.json`) na raiz do projeto (`cwd`):

1. **Se o grafo existir:**
   - Trate dúvidas sobre arquitetura, topologia de módulos, relações entre arquivos e análise de impacto ("onde está X", "o que chama Y", "quais componentes são afetados por Z") consultando **primeiro o grafo**:
     - Leia `graphify-out/GRAPH_REPORT.md` para visão macro da arquitetura.
     - Execute `graphify query "<pergunta>"`, `graphify explain "<nó>"`, `graphify path "<origem>" "<destino>"` ou `graphify affected`.
   - Só utilize busca textual bruta (`grep` / `ripgrep`) ou leitura sequencial de arquivos para confirmar detalhes finos de implementação ou quando o grafo não cobrir o artefato procurado.
   - Ao despachar subagentes exploradores para dentro do repositório, instrua-os explicitamente a consultar o grafo primeiro.
   - Se o código tiver mudado substancialmente desde a última extração (ver `graphify-out/manifest.json`), sugira atualizar o grafo (`graphify update .` ou `/graphify <path> --update`).
2. **Se o grafo não existir:**
   - Prossiga normalmente com buscas diretas (`grep` e leitura direcionada) e apenas mencione que um grafo pode ser gerado com `/graphify` caso o repositório seja grande ou demande múltiplas análises arquiteturais. Nunca construa o grafo sem solicitação do usuário.
3. **Consultas entre múltiplos repositórios:**
   - Para mapear fronteiras entre repositórios distintos, combine os grafos em um diretório local não versionado (ex.: `.claude/`) usando `graphify merge-graphs <repoA>/graphify-out/graph.json <repoB>/graphify-out/graph.json --out .claude/merged-graph.json`.

---

## 4. Higiene de Git, Branches e Documentação Viva

### 4.1 Trabalho Direto na Branch Atual (Sem Worktrees Automáticos)
- Toda edição deve ocorrer diretamente na branch com checkout ativo no diretório de trabalho atual (`cwd`).
- **Nunca** execute `EnterWorktree`, `git worktree add` ou crie isolamentos em worktrees secundários por conta própria. Só utilize worktrees se o usuário solicitar explicitamente na sessão corrente.
- Em workspaces que agrupam múltiplos repositórios independentes, sempre confirme o repositório alvo com `git rev-parse --show-toplevel` antes de qualquer operação de stage ou commit.

### 4.2 Padrão de Commits e Proibição de Co-Autoria
- Escreva mensagens de commit sempre em **português (PT-BR)**: primeira linha concisa no modo imperativo, seguida (quando aplicável) de linha em branco e bullets objetivos descrevendo as mudanças funcionais.
- **Jamais insira `Co-Authored-By`** ou qualquer forma de assinatura, crédito ou menção de autoria/co-autoria de IA em mensagens de commit, descrições de Pull Request, tags ou comentários — nem ao executar o comando diretamente, nem ao sugerir o texto para o usuário.

### 4.3 Documentação Viva (`CLAUDE.md` / `AGENTS.md` de Projetos)
- Qualquer alteração de código que modifique fluxos, contratos, estrutura de pastas ou convenções documentadas no `CLAUDE.md` / `AGENTS.md` do projeto exige a atualização correspondente do documento **na mesma sessão**, antes de concluir a tarefa.
- A documentação do projeto deve descrever **exclusivamente o estado atual** do sistema, como se nenhuma versão anterior tivesse existido:
  - Reescreva o trecho atualizado sem registrar histórico temporal ("antes era X", "agora passou a ser Y", "removido na refatoração Z") — o histórico pertence ao `git log`.
  - Não inclua detalhes triviais facilmente legíveis no código; documente arquitetura, invariantes, armadilhas e decisões não-óbvias.
  - Mantenha backlogs de dívida técnica ou planos futuros em documentos separados, sem referenciá-los ou misturá-los à descrição do estado atual.

### 4.4 Isolamento de Artefatos Locais de IA (`.git/info/exclude`)
- Em repositórios de código compartilhados ou espelhados em servidores remotos, arquivos e diretórios de suporte a agentes (`/CLAUDE.md`, `/AGENTS.md`, `/.claude/`, `/.agents/`, `/.orq/`, `/graphify-out/`, `/plano-*.md`) devem permanecer fora do controle de versão usando **exclusivamente `.git/info/exclude`** (exclusão local por clone, com padrões ancorados na raiz `/`).
- **Nunca** adicione entradas de ferramental pessoal de IA ao `.gitignore` versionado de um projeto de aplicação, evitando poluir o histórico remoto com rastros de ferramentas locais.

### 4.5 Organização de Artefatos de Planejamento e Revisão
- Planos e especificações do fluxo Superpowers devem ser gravados em `.claude/superpowers/specs/` e `.claude/superpowers/plans/`.
- Relatórios de auditoria/revisão adversarial de planos ficam em `.claude/plan-reviews/` e relatórios de encerramento em `.claude/plan-finishes/`.
- Artefatos temporários de orquestração, debates e saídas de CLI externo ficam em `.orq/`.

---

## 5. Ambiente Windows e PowerShell 5.1

- **Evite redirecionamento de shell para criar arquivos UTF-8:** no Windows PowerShell 5.1 (`powershell.exe`), operadores como `>` e `Out-File` gravam por padrão em **UTF-16 LE**, corrompendo arquivos de código, JSON e Markdown esperados em UTF-8. Utilize sempre as ferramentas nativas de escrita de arquivo do agente para criar ou editar artefatos.
- **Encoding de scripts `.ps1`:** o Windows PowerShell 5.1 interpreta arquivos `.ps1` em UTF-8 **sem BOM** como Windows-1252 (ANSI), corrompendo literais de texto com acentuação. Ao criar ou editar scripts `.ps1` que contenham caracteres acentuados, preserve **UTF-8 com BOM** ou utilize apenas caracteres ASCII/escapes seguros no código-fonte.
- **Encoding de hooks Git (`#!/bin/sh`):** scripts executados pelo `sh` do Git for Windows (como hooks em `.git/hooks/`) devem ser gravados estritamente em **UTF-8 sem BOM** e com quebras de linha **LF**.
