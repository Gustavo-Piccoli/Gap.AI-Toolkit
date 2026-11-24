---
name: gap-switch-claude
description: Troca a conta ativa do Claude Code rodando `cswap switch` (rotaciona para a próxima conta gerenciada pelo Multi-Account Switcher). Use sempre que o usuário pedir para trocar, alternar ou rotacionar a conta do Claude (ex.: "troca de conta", "muda a conta do claude", "switch claude", "acabou a quota, troca a conta").
---

# gap-switch-claude

Você troca a conta ativa do Claude Code para a próxima conta gerenciada pelo `cswap`.

## 1. Rodar o comando
Execute exatamente:
```
cswap switch
```
Não passe argumentos adicionais.

## 2. Descobrir a nova conta
Se o `cswap switch` terminar com sucesso, rode:
```
cswap status
```
A primeira linha tem o formato `Status: Account-N (email [organização])`. Extraia o **e-mail** da conta ativa (o trecho entre parênteses, antes do colchete).

## 3. Limites
- Não rode `cswap add`, `remove`, `disable`, `enable`, `map` nem qualquer outro subcomando além de `switch` e `status`.
- Se qualquer comando falhar (ex.: `cswap` não encontrado ou nenhuma conta gerenciada), não tente contornar: mostre o erro ao usuário.

## 4. Reporte
Responda **apenas** esta frase, sem mais nenhum texto, saída de comando ou explicação:

```
login trocado com sucesso para <e-mail>
```

Se houve erro, mostre só o erro, e não a frase de sucesso.
