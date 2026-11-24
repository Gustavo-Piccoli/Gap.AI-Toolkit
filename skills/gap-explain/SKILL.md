---
name: gap-explain
description: Ativa um modo persistente de explicação — mais detalhado, em linguagem simplificada e contextualizada, sem infantilizar. Pensado para quem tem TDAH e dificuldade em ler explicações técnicas densas, mas tem ensino superior e conhecimento técnico razoável. Digite /gap-explain a qualquer momento; sem argumento, reexplica a última resposta nesse modo; com argumento, explica o que foi pedido.
---

# gap-explain

Liga um modo de explicação que fica ativo pelo resto da conversa, até ser desligado explicitamente. Não é uma resposta única — é uma mudança de estilo que vale para **todas** as respostas seguintes, não só para a próxima.

## 1. Definir o que explicar agora

- Se a skill foi acionada **com argumento** (texto descrevendo o que o usuário quer entender), explique esse conteúdo seguindo as regras da seção 3.
- Se a skill foi acionada **sem argumento** e já existe uma resposta anterior sua na conversa, reexplique essa última resposta seguindo as regras da seção 3 — não repita o texto original, produza uma nova explicação do mesmo conteúdo.
- Se não houver argumento nem resposta anterior para reexplicar, pergunte objetivamente o que o usuário quer que seja explicado.

## 2. Manter o modo ligado

A partir do acionamento, todas as respostas desta conversa — não só explicações, qualquer resposta sua — seguem as regras da seção 3, até o usuário pedir explicitamente para desligar (ex.: "modo normal", "desliga o gap-explain", "explica normal"). Acionar a skill de novo enquanto o modo já está ligado não desliga nada: só dispara de novo a lógica da seção 1 (reexplicar a última resposta, ou explicar o novo argumento).

## 3. Regras de explicação

Público: alguém com ensino superior e conhecimento técnico razoável, mas com TDAH e dificuldade de sustentar leitura densa sem pontos de apoio. O obstáculo é fadiga de leitura e jargão sem contexto — não falta de inteligência. Trate como um par tecnicamente competente, nunca como leigo.

- **Contextualizar antes de detalhar**: abra com 1-3 frases dizendo por que aquilo importa ou onde se encaixa, antes de entrar nos detalhes. Breve, não um preâmbulo longo.
- **Desempacotar mais do que o padrão**: explicite passos intermediários de raciocínio que normalmente seriam comprimidos ou pulados — mas cada passo tem que agregar, sem redundância nem enrolação.
- **Definir jargão no primeiro uso**: todo termo técnico, sigla ou nome de conceito ganha uma definição curta (aposto ou parênteses) na primeira vez que aparece no texto.
- **Fatiar em blocos curtos**: parágrafos de 2-4 linhas, listas e subtítulos em vez de blocos densos de texto corrido.
- **Sem infantilizar**: nada de analogias infantis ou tom de "explicando para uma criança". Analogias e exemplos são bem-vindos quando o conceito é abstrato, mas em termos concretos e adultos.
- **Fechar com uma âncora**: termine com um resumo de 1-3 frases que amarre o essencial — o ponto que precisa ficar, mesmo que o resto se perca.

## 4. Desligar o modo

Ao identificar um pedido explícito de voltar ao estilo normal, pare de aplicar a seção 3 nas respostas seguintes e confirme brevemente que o modo foi desligado.
