---
name: gap-fluxo
description: Orquestra um pedido de desenvolvimento do início ao fim usando spec-kit (specify/clarify/plan/tasks/analyze/implement), decide tarefa a tarefa na fase de execução entre subagente nativo (Agent no Claude Code / invoke_subagent no Antigravity) ou Antigravity CLI (agy) via agentchattr, commita por fase concluída (com confirmação do usuário) e mantém o CLAUDE.md atualizado ao final. Use quando o usuário disser "/gap-fluxo" seguido de um pedido de implementação, correção ou investigação de código.
---

# gap-fluxo

Skill autoral para orquestrar pedidos de desenvolvimento
combinando spec-kit (disciplina de especificação) e agentchattr
(coordenação com o Antigravity CLI / `agy`), com foco em qualidade,
eficiência de tokens e visibilidade das decisões tomadas.

## Persona e estilo de comunicação

Comunique-se em português, de forma enxuta — sem filler, cortesias
("claro!", "ótima pergunta") ou hedging desnecessário. Frases e
gramática completas sempre (não é modo telegráfico/fragmentado). Corte
o que não muda o entendimento; mantenha o que muda.

Regras concretas:
- Sem narração de chamada de ferramenta ("vou rodar o comando X agora").
  Rode e reporte o resultado relevante.
- Sem tabelas ou listas decorativas quando texto corrido resolve.
- Termos técnicos, nomes de código, comandos, mensagens de erro: sempre
  verbatim, nunca parafraseados ou abreviados.
- Passos rotineiros já previstos no plano não precisam de narração
  passo a passo — narre decisões, bloqueios e desvios, não execução
  mecânica.

**Exceção**: quando o usuário sinalizar dúvida ou pedir mais detalhe,
troque para modo detalhado — explique com profundidade e em linguagem
simples, sem economizar clareza por brevidade. Volte ao modo enxuto
depois que a dúvida for resolvida.

Isso vale para a comunicação com o usuário. Não afeta o conteúdo
técnico de specs/planos/tasks (que seguem seu próprio formato) nem as
mensagens de commit (formato próprio, ver seção de commits).

## Visão geral do fluxo

```
1. Recebe o pedido
2. Roda TODAS as etapas do spec-kit por padrão:
   specify → clarify → plan → tasks → analyze → implement
3. Se julgar uma ou mais etapas dispensáveis, PERGUNTA antes de pular
   (pode agrupar várias etapas numa única pergunta)
4. Fase de DEFINIÇÃO (specify, clarify, plan, tasks): qualquer leitura
   de código usa subagente nativo — nunca agy. Perguntas de
   clarificação em rodada única por etapa, depois de investigar.
5. Fase de EXECUÇÃO (a partir de implement, e qualquer investigação/
   trabalho pós-tasks): decide por tarefa entre subagente nativo e agy,
   usando os 4 critérios. Ao fim de cada fase do Master Checklist,
   testa, e propõe commit (com confirmação do usuário) via subagente.
6. Se o escopo mudar de forma que o plano não cobre mais o que está
   sendo feito, PARA e pergunta de novo
7. Testa, revisa, e pede aprovação final de conclusão
8. Atualiza o CLAUDE.md refletindo o que mudou (uma vez, ao final)
9. Registra cada decisão de executor no log local do repositório
```

## Pular etapas do spec-kit

O padrão é rodar todas as etapas: `/speckit.specify`, `/speckit.clarify`,
`/speckit.plan`, `/speckit.tasks`, `/speckit.analyze`, `/speckit.implement`.

Se, ao longo do fluxo, você julgar uma ou mais etapas dispensáveis para o
pedido em questão, **pergunte ao usuário antes de pular** (via conversa ou `AskUserQuestion` no Claude Code / `ask_question` no Antigravity) — nunca pule
uma etapa sem confirmação explícita. Quando mais de uma etapa parecer
dispensável ao mesmo tempo, agrupe numa única pergunta em vez de perguntar
etapa por etapa, por exemplo:

```
Acho que dá para pular /speckit.clarify e /speckit.analyze neste pedido
(escopo já está bem definido e é uma mudança pontual em um arquivo só).
Posso pular as duas, ou prefere que eu rode alguma delas mesmo assim?
```

O usuário também pode pedir para pular qualquer etapa a qualquer momento
da sessão — nesse caso, apenas confirme e siga, sem precisar repetir a
pergunta.

## Fase de definição (specify → clarify → plan → tasks)

Nesta fase, **nunca use `agy`**. Se precisar ler código para embasar a
especificação ou o plano:

1. Primeiro, use o contexto que o `CLAUDE.md` do repositório já fornece
   (arquitetura, convenções, stack) — não releia arquivos que o `CLAUDE.md`
   já descreve suficientemente bem.
2. **Verificação leve de alinhamento**: trate o `CLAUDE.md` como a fonte
   primária, mas não como verdade automática — se houver sinal concreto
   de que ele pode estar defasado (ex: o repositório está em uma branch
   diferente da que o `CLAUDE.md` parece descrever, ou algo que ele
   afirma contradiz o que você vê no código durante a investigação),
   confira o ponto específico contra o estado real antes de seguir. Não
   é uma releitura completa do repositório a cada execução — só uma
   checagem pontual quando o sinal de defasagem aparece.
3. Se o `CLAUDE.md` não for suficiente para uma etapa específica (ex: o
   pedido menciona uma função/arquivo cujo comportamento atual precisa
   ser conferido), delegue essa leitura a um **subagente nativo** (via tool `Agent` no Claude Code / `invoke_subagent` no Antigravity), com escopo restrito ao que for necessário para aquela
   etapa. Isso isola o custo de leitura do contexto do Principal.
4. `agy` fica reservado para a fase de execução (abaixo) — mesmo que a
   leitura de código necessária na fase de definição seja grande, use
   subagente nativo, não `agy`.

### Perguntas de clarificação em rodada única

Ao chegar numa etapa que precisa de input do usuário (tipicamente
`/speckit.clarify`, mas também qualquer pergunta de "pular etapa"),
investigue primeiro (código, CLAUDE.md, contexto já disponível) e só
depois pergunte — nunca pergunte algo que a investigação já responde.

Reúna **tudo** que for essencial para prosseguir numa única mensagem (ou via `AskUserQuestion` no Claude Code / `ask_question` no Antigravity),
em vez de perguntas soltas em sequência. Quando houver uma opção
razoável, ofereça-a com uma recomendação (ex: "Recomendo X porque Y,
mas pode ser Z se preferir") — isso reduz o esforço do usuário de
decidir do zero. Numeração não é obrigatória, mas garanta cobertura
completa: antes de perguntar, confira internamente que nada essencial
ficou de fora, porque uma segunda rodada de perguntas evitável é
exatamente o que este formato existe para evitar.

Só volte a perguntar fora dessa rodada se uma dúvida genuinamente nova
surgir de uma resposta do usuário — algo que não dava para prever antes
de saber a resposta anterior. Isso deve ser exceção, não padrão.

## Fase de execução (a partir de implement, e trabalho pós-tasks)

Depois que o plano de tarefas existe (`/speckit.tasks` concluído, ou
etapas puladas até esse ponto), decida o executor de cada tarefa usando
estes 4 critérios como piso objetivo, com julgamento nos casos de
fronteira:

- (a) número de arquivos que a tarefa provavelmente toca
- (b) exige investigação/exploração ampla do código existente?
- (c) é independente de outras tarefas do plano (paralelizável)?
- (d) envolve escrita de código substancial, não só ajuste pontual?

Regra prática: 2+ critérios positivos → `agy` via agentchattr. 0-1 →
subagente nativo (`Agent` no Claude Code / `invoke_subagent` no Antigravity).

Isso também vale para qualquer investigação pesada que surja durante a
execução (ex: debate sobre abordagem, verificação ampla de implementação
existente antes de decidir como prosseguir) — não só para escrever
código novo.

**Limite de paralelismo**: no máximo **3 instâncias de `agy` simultâneas**
(`agy`, `agy-2`, `agy-3`). Se houver mais de 3 tarefas candidatas a `agy`
ao mesmo tempo, enfileire as excedentes.

### Como acionar `agy`

1. Rode `scripts/agentchattr.sh ensure` (via Bash) para garantir que o
   servidor está de pé — isso **não gasta tokens**, é só subir um
   processo HTTP local.
2. Para uma instância nova, rode `scripts/agentchattr.sh spawn-agy`
   (sem argumento). Para uma 2ª ou 3ª instância simultânea, rode o
   mesmo comando de novo — o servidor atribui o slot sozinho (`agy`,
   `agy-2`, `agy-3`), não é algo que se passa como argumento.
3. Conecte-se ao canal via MCP (`chat_send`/`chat_read`) e @mencione a
   instância com a tarefa.
4. Aguarde a resposta. Isso é síncrono — o Principal fica ocupado
   coordenando, mas não gera o código em si (a economia de tokens Claude
   vem daí, não de paralelismo real no sentido de liberar a conversa).
5. **Sem timeout automático.** Se `agy` estiver demorando, o usuário
   acompanha manualmente pelo terminal da instância ou pela UI web do
   agentchattr (`http://127.0.0.1:8300`) — não interrompa nem alerte
   por demora sozinho. Ver `NOTES.md` para a justificativa de design
   dessa decisão.

## Gatilho para parar e perguntar de novo

Mesmo já com um plano aprovado (implícito ou explícito), pare a execução
e pergunte ao usuário se:

- O escopo real da implementação diverge do que o plano/spec previa (ex:
  descobriu-se que a mudança precisa tocar um módulo não previsto).
- Duas tarefas que pareciam independentes (por isso rodando em paralelo)
  se revelam conflitantes na prática (ex: mesmo arquivo, mudança
  incompatível) — trate isso como um caso concreto de "escopo diverge
  do plano".
- Um executor (subagente ou `agy`) reporta um bloqueio que exige decisão
  de produto/negócio, não só técnica.
- Uma tarefa marcada como pequena se revela, na prática, muito maior do
  que o previsto.

Não pare por incertezas menores que um executor competente resolveria
sozinho (ex: escolha de nome de variável, pequenos detalhes de estilo).

## Commit por fase concluída

Ao fim de cada fase do Master Checklist gerado por `/speckit.tasks`
(não ao fim de cada tarefa individual, nem só ao fim de tudo):

1. **Teste restrito à fase.** Rode os testes relevantes ao que aquela
   fase entrega — não a suíte inteira. Se a suíte completa falhar por
   causa de trabalho de fases futuras ainda não implementadas, isso não
   bloqueia o commit da fase atual (não é uma falha da fase concluída).
   Se um teste relevante à própria fase falhar, não decida sozinho como
   proceder — pergunte ao usuário o que fazer e resolvam juntos.
2. **Peça confirmação antes de commitar.** Informe ao usuário, de forma
   enxuta, que a fase N está pronta (resumo curto do que foi entregue) e
   pergunte se pode commitar. Só prossiga com confirmação explícita —
   nunca commite (e principalmente nunca dê push) sem essa confirmação,
   mesmo que o teste tenha passado.
3. **Delegue o commit a um subagente.** Depois de confirmado, despache
   um subagente nativo (`Agent` no Claude Code / `invoke_subagent` no Antigravity) com as instruções da seção "Reuso do
   gap-commit" abaixo. O subagente executa stage → commit → sync →
   push isoladamente e reporta de volta só o resultado final (resumo da
   mensagem usada + confirmação de push) — isso evita poluir o contexto
   principal com a saída intermediária de `git status`/`git diff`/
   `git log`.
4. **Correção após commit de fase.** Se, em uma fase posterior, for
   necessário corrigir algo que já foi commitado, crie um **novo commit
   de correção (fixup)** — nunca `--amend` ou reescreva o histórico de
   um commit de fase já enviado ao remoto.

### Reuso do gap-commit

O subagente despachado no passo 3 acima segue exatamente o fluxo da
skill `gap-commit` (contorno de proxy para comandos que tocam o
remoto, stage com checagem de segredos, mensagem em português no
formato resumo+tópicos funcionais sem menção de autoria de IA, sync via
rebase antes do push, nunca `--force`/`--no-verify`). Se `gap-commit`
estiver disponível como skill separada no ambiente, invoque-a
diretamente; caso contrário, siga as etapas descritas em
`references/gap-commit-reference.md`.

## Log de decisões

Registre cada decisão de executor num arquivo `gap-fluxo-log.md`, na
**raiz do repositório onde a skill está sendo usada** (crie o arquivo se
não existir; sempre faça append, nunca sobrescreva). Este log é só para
auditoria posterior do usuário — a skill nunca lê nem usa este arquivo
para tomar decisões.

Use este formato de linha fixo, um por tarefa/decisão:

```
## <YYYY-MM-DD HH:MM> — <resumo curto do pedido>
- Etapas puladas: <lista, ou "nenhuma">
- Tarefa: <descrição curta> | Executor: <subagente|agy|agy-2|agy-3> | Critérios: <quais dos 4 bateram, ex: "b,d">
- Commit de fase: <fase> | <hash curto ou "pendente confirmação">
```

## Teste e revisão final

Depois que todas as tarefas do plano forem concluídas:

1. Rode os testes relevantes (ou peça ao executor que os rodou para
   confirmar o resultado) — dessa vez a suíte completa, não restrita a
   uma fase.
2. Resuma o que foi feito, por qual executor, e qualquer desvio do plano
   original (etapas puladas, mudanças de escopo confirmadas com o
   usuário).
3. Peça aprovação final antes de considerar a tarefa como concluída.
4. **Atualize o CLAUDE.md** refletindo mudanças de arquitetura,
   convenções ou estrutura introduzidas por esta execução — uma única
   vez, aqui no final (não a cada fase). Pode delegar essa atualização a
   um subagente com acesso ao diff completo da execução. Se nada
   relevante mudou para o CLAUDE.md, não crie edição artificial só para
   ter uma.
