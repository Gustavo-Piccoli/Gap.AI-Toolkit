# Notas de design — gap-fluxo

Justificativas de decisões que não são óbvias a partir do SKILL.md ou
do script sozinhos. Não é lido pela skill em tempo de execução — é só
para consulta humana (ou de uma IA editando a skill) quando o "porquê"
de uma escolha não estiver claro.

## Sem timeout automático / sem reatribuição de `agy` travado

Quando `agy` demora, a skill não reatribui a tarefa automaticamente
para o subagente nativo, mesmo isso parecendo uma melhoria óbvia. Isso
é intencional, não uma lacuna a preencher:

- O Principal não tem visibilidade suficiente para distinguir
  "investigação legítima grande" de "travamento" (`agy -p` já mostrou
  instabilidade via subprocess no passado).
- Trocar de executor no meio de uma tarefa com estado parcial (arquivos
  meio-editados) é arriscado sem saber exatamente o que já foi feito.
- O usuário prefere decidir isso manualmente, com contexto que a skill
  não tem (reconhecer se aquele tipo de tarefa costuma demorar, se o
  padrão bate com travamento conhecido, etc).

A UI local do agentchattr (`http://127.0.0.1:8300`) existe justamente
para permitir esse acompanhamento manual — mantenha-a como canal de
observação do usuário, não como algo que a skill consulta ou aciona.

## Sem verificação de instâncias `agy` de sessões anteriores

O script `agentchattr.sh` não tem comando `list`/`status` por instância
e não verifica, antes de um `spawn-agy`, se `agy`/`agy-2`/`agy-3` já
estão em uso por uma sessão anterior. Isso é intencional: o usuário não
trabalha com sessões concorrentes empilhadas e prefere não pagar o
overhead de uma checagem de estado remoto a cada spawn. Não adicione
essa verificação como "melhoria" sem que o usuário peça.

## Ambiente assumido: Windows nativo

O script assume Windows nativo (`cmd.exe`/`start.bat`/PowerShell), sem
WSL. É a única plataforma usada — não generalize as chamadas do script
para outros SOs sem indicação explícita do usuário.

## Critérios de decisão de executor: por que 4 e não menos

Já foi cogitado colapsar os 4 critérios (número de arquivos,
investigação ampla, paralelizável, código substancial) em 2 pares
compostos ("Tamanho" e "Autonomia"), já que na prática eles tendem a
andar juntos. A simplificação foi revertida porque mudava o
comportamento: com 4 critérios, "2+ positivos" é um piso relativamente
generoso (ex: só "investigação ampla" + "código substancial" já manda
para `agy`, mesmo sem tocar muitos arquivos nem ser paralelizável).
Colapsado em 2 pares, "2 positivos" vira exigir os dois pares ao mesmo
tempo (AND), um piso mais alto e mais conservador do que o original.
Se uma simplificação futura for cogitada de novo, garanta que o limiar
de decisão (quais tarefas acabam indo para `agy`) continue equivalente
ao atual, não só que o número de critérios diminua.

## Commit por fase: escopo do teste e trigger de confirmação

O commit por fase do Master Checklist foi desenhado com dois cuidados
que não são óbvios olhando só o SKILL.md:

- **Teste restrito à fase, não a suíte inteira.** Fases sequenciais de
  um plano (ex: "criar entidades" antes de "criar endpoint que as usa")
  costumam deixar a suíte completa vermelha por causa de trabalho de
  fases futuras ainda não implementadas — isso não é uma falha real da
  fase concluída. Rodar a suíte inteira a cada fase geraria falsos
  bloqueios constantes em qualquer plano com dependência entre fases.
  Testar só o que a fase concluída entrega evita esse ruído. Se mesmo
  assim um teste relevante à fase falhar, a skill pergunta ao usuário
  em vez de decidir sozinha — o usuário optou por resolver isso caso a
  caso, não por uma regra automática de bloqueio/prosseguimento.
- **Confirmação do usuário antes do commit, não só antes do push.**
  Cogitou-se automatizar o commit por fase (já que a skill decide
  quando uma fase termina), mas o usuário preferiu manter confirmação
  explícita antes de qualquer commit — decisão consciente de aceitar
  uma troca de mensagem a mais por fase, porque commit/push é uma ação
  que sai do controle imediato dele (principalmente o push, que é
  efetivamente irreversível na prática). O subagente que executa o
  commit em si só é despachado depois da confirmação, e reporta de
  volta apenas o resultado final — a poluição de contexto (diff,
  status, log) fica isolada nele, não no Principal.
- **Fixup em vez de amend.** Correções a um commit de fase já enviado
  ao remoto viram um commit novo, nunca reescrita de histórico —
  consistente com a regra que já existia em `gap-commit` para hooks
  de pre-commit falhos, só estendida para esse caso.

Granularidade "1 commit por fase do Master Checklist" foi adotada como
teste — o usuário sinalizou que pode ajustar se, na prática, uma fase
não corresponder bem ao que ele considera "uma feature" (ex: uma fase
de puro setup/infra, sem entrega de feature em si).

## Persona: nível "lite", não "full"

A comunicação enxuta da skill mantém gramática e frases completas —
não é modo fragmentado/telegráfico. A ideia foi inspirada em uma skill
de compressão de prosa (níveis lite/full/ultra), mas só o padrão de
regras foi incorporado (cortar filler/cortesia/hedging/narração de
tool-call/tabelas decorativas), não a skill em si como dependência
externa, e não os níveis mais agressivos de compressão — o usuário
quer eficiência de leitura, não fragmentos que arriscam ambiguidade,
especialmente durante a rodada de perguntas de clarificação.
