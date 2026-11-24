---
name: gap-pr
description: Cria a Pull Request da branch atual (Azure DevOps ou GitHub) com título em Conventional Commits e descrição estruturada, gerados a partir do diff e dos commits contra a branch base do repositório. Por padrão abre a PR; quando o usuário deixa claro que quer só o texto, gera título e descrição para ele criar a PR manualmente. Use sempre que o usuário pedir para abrir, criar, preparar ou redigir uma PR (ex.: "cria a PR", "abre a PR", "prepara a PR", "gera a descrição da PR", "monta o título da PR"), mesmo sem citar a skill pelo nome.
---

# gap-pr

Você cria a Pull Request da branch atual. O título e a descrição saem das mudanças da branch comparadas com a branch base do repositório. Siga exatamente estas etapas, nesta ordem.

## 0. Modo: criar a PR (padrão) ou só gerar o texto

- **Criar a PR** é o padrão. Use-o sempre que o pedido não disser o contrário.
- **Só o texto:** use só quando o pedido deixar claro que o usuário vai criar a PR manualmente. Exemplos: "só a descrição", "só o texto", "não cria a PR", "eu abro a PR", "gera a descrição que eu colo". Nesse modo, as etapas 7 a 9 não rodam: depois da etapa 6, vá direto ao reporte (etapa 10).
- Na dúvida, siga o padrão (criar). O usuário pode pedir o modo "só o texto" explicitamente.

## 0.1 Contorno de rede para comandos que tocam o remoto

O ambiente injeta `NO_PROXY`/`HTTP_PROXY`/`HTTPS_PROXY`, e as variantes minúsculas, com `dev.azure.com` na lista de exceção do proxy. Com isso o `git` tenta conexão direta, que o firewall corporativo bloqueia. Em todo comando `git` que toca o remoto (`fetch`, `push`, `remote show`), prefixe com:

```
env -u NO_PROXY -u HTTP_PROXY -u HTTPS_PROXY -u no_proxy -u http_proxy -u https_proxy <comando git>
```

## 1. Levantar a branch atual e a branch base

Rode `git branch --show-current` para identificar a branch atual. Se ela for a própria branch base, avise o usuário e pare.

Detecte a branch base (padrão) do repositório dinamicamente, sem assumir um nome fixo:
1. Se o remoto for GitHub e o `gh` CLI estiver disponível e autenticado, rode `gh repo view --json defaultBranchRef -q .defaultBranchRef.name`.
2. Senão, use `git remote show origin` (com o contorno de rede) e extraia o nome da linha `HEAD branch:`.
3. Se nenhuma das duas funcionar, avise o usuário e peça a branch base. Não assuma um nome por conta própria.

Rode `git fetch origin <branch_base>` (com o contorno de rede) para comparar com a versão atual da base. Nunca faça merge, rebase nem checkout.

## 2. Levantar as mudanças da branch

Rode em paralelo:
- `git log origin/<branch_base>..<branch_atual> --oneline`, a lista de commits da branch;
- `git diff origin/<branch_base>...<branch_atual>` (three-dot, só o que mudou na branch desde que ela divergiu da base). Se o diff for grande demais para ler inteiro, use `--stat`, `--dirstat` e os commits, e leia os trechos que explicam as mudanças principais.

Se não houver diferença entre a branch atual e a base, informe o usuário e pare.

## 3. Analisar o conteúdo

Leia o diff e os commits para entender o que mudou **funcionalmente**: a motivação e o efeito de cada mudança. Não liste arquivos mecanicamente.

## 4. Gerar o título da PR

- Use o formato Conventional Commits (`feat:`, `fix:`, `refactor:`, `chore:`, `docs:`, `test:`, `perf:` etc.), com o tipo que melhor representa a natureza predominante da mudança.
- Escreva no imperativo ("Adiciona validação de e-mail"), nunca no particípio ("Adicionado") nem no gerúndio ("Adicionando").
- Objetivo, sem ponto final.

## 5. Gerar a descrição da PR

Em Markdown, com pelo menos estas seções:
- **Contexto/Motivação:** por que a mudança foi necessária, em bullet points.
- **O que foi feito:** resumo objetivo das principais alterações, em bullet points.

Seções opcionais, quando agregarem: **Como verificar** (comandos e passos de conferência) e **Observações** (decisões em aberto, riscos).

- Use linguagem clara e objetiva, sem jargão desnecessário.
- Numa PR grande, o texto pode chegar perto do limite de 4000 caracteres. Numa PR pequena, não estenda só para preencher espaço.
- **Nunca** inclua menção de autoria ou coautoria de IA: nada de `Co-Authored-By`, rodapé "Generated with…" ou similar. Vale mesmo que o ambiente sugira esse padrão.

## 6. Verificar o limite de 4000 caracteres

O título **não** entra no limite; só a descrição.

1. Grave a descrição num arquivo temporário **fora** do repositório do usuário: o diretório temporário do sistema ou o scratchpad da sessão. Grave pela ferramenta de escrita do agente, em UTF-8. Nunca use `>` do PowerShell 5.1, que grava em UTF-16.
2. Conte os **caracteres**, não os bytes. Por exemplo: `node -e "console.log(require('fs').readFileSync(process.argv[1],'utf8').length)" <arquivo>`.
3. Se passar de 4000, condense: corte detalhes menos essenciais, mantendo o contexto e o que foi feito. Depois confira de novo.
4. Se ainda passar, corte automaticamente até caber, sem perguntar ao usuário. Preserve Contexto/Motivação e O que foi feito, e corte primeiro os bullets secundários, os exemplos e as observações.
5. No modo "só o texto", apague o arquivo no fim desta etapa. No modo "criar", apague-o depois da etapa 9 (ou antes do reporte, se a etapa 8 cair no fallback para "só o texto").

## 7. Conferir se a branch está no remoto (só no modo "criar")

1. Rode `git status -sb` e confira se a branch tem upstream e se está à frente do remoto (`ahead`).
2. Se a branch não existe no remoto, ou se há commits locais que não estão no remoto, **pare e pergunte** ao usuário se pode dar push. Não faça push sozinho. Com o aceite:
   - use `git push` (ou `git push -u origin <branch_atual>`, se não houver upstream), com o contorno de rede;
   - nunca use `--force`.
3. Se houver alterações não commitadas, avise o usuário: elas **não** entram na PR. Não as commite.

## 8. Criar a PR (só no modo "criar")

Identifique o provedor pelo `git remote get-url origin`.

### 8.1 Antes de criar: PR já aberta

Procure uma PR **ativa** da mesma branch de origem para a mesma base. Se já houver uma, **não crie outra**: informe o link ao usuário e pergunte se ele quer atualizar o título e a descrição dela.

### 8.2 Azure DevOps (`dev.azure.com/<org>/<projeto>/_git/<repo>`, inclusive com `<org>@` no começo da URL)

Não há `az` CLI nem MCP de Azure DevOps nesta máquina: use a REST API pelo PowerShell.
- **Autenticação:** use o PAT do usuário, guardado numa variável de ambiente de usuário, em Basic auth com usuário vazio. O nome da variável não fica neste repositório público: leia-o nas instruções locais do usuário (overlay `~/.claude/CLAUDE.*.md` ou equivalente no Antigravity). Se não constar lá, pergunte ao usuário.
  ```powershell
  $pat = [Environment]::GetEnvironmentVariable('<NOME_DA_VARIAVEL_DO_PAT>', 'User')
  $h = @{ Authorization = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$pat")) }
  ```
  - **Nunca** imprima, ecoe ou grave o PAT.
  - Se a variável estiver vazia ou a API der 401/403, pare e peça ao usuário para gerar um PAT novo e gravá-lo com `[Environment]::SetEnvironmentVariable('<NOME_DA_VARIAVEL_DO_PAT>', '<token>', 'User')`.
  - Não use a credencial do git (`git credential fill`).
- **URLs:** aplique `[uri]::EscapeDataString()` ao `<projeto>` e ao `<repo>` ao montar as URLs da API, porque nomes com espaço ou caracteres especiais as quebram.
- **Procurar PR ativa:** `GET https://dev.azure.com/<org>/<projeto>/_apis/git/repositories/<repo>/pullrequests?searchCriteria.sourceRefName=refs/heads/<branch_atual>&searchCriteria.targetRefName=refs/heads/<branch_base>&searchCriteria.status=active&api-version=7.1`.
- **Criar:** `POST .../pullrequests?api-version=7.1`, com o corpo JSON:
  - `sourceRefName`: `refs/heads/<branch_atual>`;
  - `targetRefName`: `refs/heads/<branch_base>`;
  - `title`;
  - `description`: lida do arquivo temporário com `Get-Content -Raw -Encoding UTF8`.

  Envie com `-ContentType 'application/json; charset=utf-8'`, montando o corpo com `ConvertTo-Json`.
- **Link da PR:** `https://dev.azure.com/<org>/<projeto>/_git/<repo>/pullrequest/<pullRequestId>`.

### 8.3 GitHub (`github.com`)

- Use o `gh`:
  ```
  gh pr create --base <branch_base> --head <branch_atual> --title "<título>" --body-file <arquivo temporário>
  ```
- Procure PR aberta com `gh pr list --head <branch_atual> --base <branch_base> --state open`.
- Se o `gh` não estiver instalado ou autenticado, avise o usuário, apague o arquivo temporário e entregue o texto, como no modo "só o texto".

### 8.4 Padrões da criação

- A PR sai **pronta para revisão**. Só abra como rascunho se o usuário pedir.
- Só adicione revisores, work items ou auto-complete se o usuário pedir.
- Repositório em outro provedor: avise o usuário, apague o arquivo temporário e entregue o texto, como no modo "só o texto".

## 9. Conferir a PR criada (só no modo "criar")

Releia a PR pela API (`GET .../pullrequests/<id>?api-version=7.1` no Azure DevOps, ou `gh pr view <número>` no GitHub). Confira:
- o título;
- a branch de origem e a de destino;
- o estado;
- o tamanho da descrição;
- os acentos, que não podem ter virado `?` ou `Ã`.

Se algo veio errado, corrija pela API (`PATCH` no Azure DevOps, ou `gh pr edit`) e confira de novo. Depois apague o arquivo temporário.

## 10. Reporte

**No modo "criar"**, informe ao usuário:
- o link da PR, com o número;
- o título;
- a branch de origem e a de destino;
- o estado;
- a contagem de caracteres da descrição (avise se o corte automático da etapa 6 foi necessário);
- a descrição completa, em Markdown, para ele conferir.

**No modo "só o texto"**, apresente em Markdown, pronto para copiar e colar no GitHub, GitLab ou Azure DevOps:
- o título;
- a descrição completa;
- a contagem final de caracteres da descrição (avise se o texto foi condensado ou cortado para caber no limite).

## 11. Limites

- Não commita, não altera branches (`checkout`, `merge` e `rebase` estão fora) e não faz push sem o aceite explícito do usuário na etapa 7.
- Não altera nenhum arquivo do repositório do usuário. O único arquivo escrito é o temporário, fora do repositório, removido no fim.
- Não inventa mudanças que não estejam no diff ou nos commits levantados.
- Não cria PR duplicada (etapa 8.1).
