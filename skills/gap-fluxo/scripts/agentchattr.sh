#!/usr/bin/env bash
# agentchattr.sh — verifica se o servidor agentchattr está de pé e, se não,
# sobe o servidor + o(s) wrapper(s) de agente pedido(s).
#
# Uso:
#   ./agentchattr.sh check                 → só verifica, não sobe nada
#   ./agentchattr.sh ensure                 → sobe o servidor se não estiver rodando
#   ./agentchattr.sh spawn-agy               → registra uma nova instância do agy
#                                              (chame de novo para agy-2, agy-3...
#                                               o servidor atribui o slot sozinho)
#
# Requer a variável AGENTCHATTR_HOME apontando para a pasta onde o
# agentchattr está instalado (ex: ~/agentchattr-0.5.0 ou C:\tools\agentchattr-0.5.0).
# Defina isso uma vez no seu perfil do PowerShell/bash, ou passe inline:
#   AGENTCHATTR_HOME="/caminho/para/agentchattr" ./agentchattr.sh ensure
#
# IMPORTANTE: subir o servidor NÃO consome tokens — é só um processo HTTP
# local (FastAPI). O gasto de tokens só acontece quando um agente conectado
# processa uma mensagem de verdade.
#
# TETO DE PARALELISMO: esta skill limita a no máximo 3 instâncias de agy
# simultâneas (agy, agy-2, agy-3). Esse limite é reforçado pela instrução
# no SKILL.md (quem decide invocar spawn-agy), não por este script — ele
# não impede uma quarta chamada se for feita manualmente.
#
# Decisões de design (sem verificação de instâncias antigas, ambiente
# Windows nativo assumido) estão documentadas em NOTES.md.

set -euo pipefail

HOST="${AGENTCHATTR_HOST:-127.0.0.1}"
PORT="${AGENTCHATTR_PORT:-8300}"
HOME_DIR="${AGENTCHATTR_HOME:-}"

if [ -z "$HOME_DIR" ]; then
  echo "ERRO: defina AGENTCHATTR_HOME apontando para a pasta de instalação do agentchattr." >&2
  exit 1
fi

is_up() {
  curl -s -o /dev/null -w "%{http_code}" "http://${HOST}:${PORT}/" 2>/dev/null | grep -q "200"
}

cmd="${1:-check}"

case "$cmd" in
  check)
    if is_up; then
      echo "agentchattr já está rodando em http://${HOST}:${PORT}"
      exit 0
    else
      echo "agentchattr NÃO está rodando"
      exit 1
    fi
    ;;

  ensure)
    if is_up; then
      echo "agentchattr já está rodando em http://${HOST}:${PORT} — nada a fazer."
      exit 0
    fi
    echo "Subindo servidor agentchattr (sem custo de tokens — é só um processo HTTP local)..."
    # Windows nativo via Git Bash, chamando start.bat através de cmd.exe /c.
    ( cd "$HOME_DIR" && cmd.exe /c "windows\\start.bat" >/dev/null 2>&1 & )
    # Aguarda até 15s o servidor responder antes de desistir
    for i in $(seq 1 15); do
      sleep 1
      if is_up; then
        echo "Servidor no ar após ${i}s."
        exit 0
      fi
    done
    echo "AVISO: servidor não respondeu em 15s. Verifique manualmente." >&2
    exit 1
    ;;

  spawn-agy)
    if ! is_up; then
      echo "Servidor não está rodando — rode '$0 ensure' primeiro." >&2
      exit 1
    fi
    # Sempre chama o wrapper com a chave "agy" do config.toml — nunca um
    # nome de instância. O servidor decide o slot (agy, agy-2, agy-3...)
    # sozinho, com base em quantas instâncias de "agy" já estão registradas.
    echo "Registrando nova instância do Antigravity CLI (sem custo de tokens até a primeira mensagem processada)..."
    ( cd "$HOME_DIR" && env NO_PROXY="127.0.0.1,localhost" python wrapper.py agy & )
    echo "Wrapper iniciado. Acompanhe manualmente via terminal ou http://${HOST}:${PORT} — não há timeout automático."
    ;;

  *)
    echo "Uso: $0 {check|ensure|spawn-agy}" >&2
    exit 1
    ;;
esac
