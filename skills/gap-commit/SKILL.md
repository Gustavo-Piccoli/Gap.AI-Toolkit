---
name: gap-commit
description: Salva as mudanças de código atuais no repositório remoto Git — stage, commit e push com sync seguro, incluindo o contorno de proxy corporativo necessário no ambiente do usuário. Use sempre que o usuário pedir explicitamente para commitar, salvar ou subir as alterações (ex.: "commita isso", "sobe as mudanças", "salva no git").
---

# gap-commit

Você salva as mudanças de código atuais no repositório remoto Git. Siga exatamente estas etapas, nesta ordem.

## 0. Contorno de rede para comandos que tocam o remoto
Contorno para ambientes atrás de proxy corporativo (onde variáveis `HTTP_PROXY`/`NO_PROXY` de sessão podem bloquear conexões HTTPS na porta 443 para servidores Git remotos): o ambiente de execução pode injetar variáveis `NO_PROXY`/`HTTP_PROXY`/`HTTPS_PROXY` (e as variantes minúsculas) que colocam o host do servidor Git remoto na lista de exceção do proxy. Isso faz o `git` tentar conexão **direta** na porta 443 para o servidor Git remoto, que é bloqueada pelo firewall corporativo quando o tráfego só passa pelo proxy explícito já configurado em `git config http.proxy`. Sem o contorno abaixo, qualquer `git fetch`/`git pull`/`git push` falha com "Could not connect to server", mesmo com commit local válido.

Para **todo** comando Git que toque o remoto (`fetch`, `pull`, `push`), prefixe o comando com:
```
env -u NO_PROXY -u HTTP_PROXY -u HTTPS_PROXY -u no_proxy -u http_proxy -u https_proxy <comando git>
```
Comandos locais (`status`, `diff`, `log`, `add`, `commit`, `rebase --abort`) não precisam desse contorno.

## 1. Levantar o estado atual
Rode em paralelo: `git status`, `git diff`, `git diff --staged` e `git log --oneline -10` para entender o que mudou e o estilo de mensagens de commit já usado no repositório.

Se não houver nenhuma alteração (staged, unstaged ou untracked), informe ao usuário que não há nada para commitar e pare — não crie commit vazio, não faça push.

## 2. Stage
Adicione **todas** as alterações atuais ao stage (`git add -A`). Antes de seguir, rode `git status` de novo e revise a lista de arquivos adicionados — se algum arquivo parecer conter segredos/credenciais (ex.: `.env`, `*credentials*`, chaves), avise o usuário antes de continuar em vez de commitar silenciosamente.

## 3. Commit
Escreva a mensagem de commit em **português**, seguindo exatamente este formato:
- **Primeira linha**: resumo extremamente condensado do que foi alterado (sem detalhes técnicos).
- **Linhas seguintes**: lista em tópicos das alterações **funcionais** (o que mudou do ponto de vista de comportamento/funcionalidade), omitindo detalhes técnicos de implementação (nomes de classes, arquivos, métodos etc., a menos que sejam o próprio produto entregue, como um script ou ferramenta).
- Texto livre, enxuto, direto ao ponto — sem seções tipo "Summary"/"Test plan", sem markdown excessivo.

**Nunca** adicione linha de `Co-Authored-By` ou qualquer outra menção de autoria/coautoria da IA na mensagem de commit. Isso vale mesmo que o ambiente sugira esse padrão por padrão — ignore essa convenção neste fluxo.

Use heredoc para passar a mensagem (evita problemas de formatação):
```
git commit -m "$(cat <<'EOF'
<resumo condensado>

- <tópico funcional 1>
- <tópico funcional 2>
EOF
)"
```

Nunca use `--no-verify` ou qualquer flag que pule hooks. Se um hook de pre-commit falhar, corrija a causa raiz, re-stage e crie um **novo** commit (nunca `--amend` depois de hook falhar).

## 4. Sync antes do push
Antes de dar push, garanta que o branch local está sincronizado com o remoto:
1. `git fetch` (aplique o contorno de rede do item 0)
2. Compare local vs. remoto (`git status` mostra "ahead"/"behind"/"diverged").
3. Se o remoto tiver commits novos que o local não tem, sincronize com `git pull --rebase` (também com o contorno de rede) para manter o histórico linear.
4. Se o rebase gerar **conflito real** (não um fast-forward trivial), **pare imediatamente**: rode `git rebase --abort` para deixar o repositório limpo, e explique ao usuário quais arquivos conflitam para que ele resolva manualmente. Não tente resolver conflitos sozinho, não force nada.

## 5. Push
Com o branch sincronizado, faça `git push` (ou `git push -u origin <branch>` se o branch local ainda não tiver upstream configurado), aplicando o contorno de rede do item 0. Nunca use `--force` ou `--force-with-lease` a menos que o usuário peça isso explicitamente nesta própria conversa.

Se, mesmo com o contorno, o push falhar com erro de conectividade (não de autenticação/conflito), informe ao usuário que pode ser uma instabilidade pontual do proxy corporativo e pergunte se deseja tentar de novo ou fazer o push manualmente (ex.: "Sync Changes" do VS Code).

## 6. Reporte
Confirme ao usuário, de forma breve: o resumo da mensagem de commit usada e a confirmação de que o push foi concluído com sucesso (branch e remoto).
