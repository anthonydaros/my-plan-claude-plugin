# My Plan — guia das skills

Sete skills independentes. Cada uma faz um único trabalho, lê e escreve
arquivos comuns dentro de `docs/`, e para. Nenhuma invocação puxa a
próxima — você decide o que rodar e quando. A única cadeia sancionada vive
*dentro* de uma invocação: `implement` constrói a tarefa e, sem perguntar
nada, segue os corpos de `review` e `commit` — revisão independente, loop
de correção até ficar verde, commit — fechando a tarefa de ponta a ponta
(`--solo` para depois da construção). Este guia cobre cada skill em
detalhe: o que ela faz, como invocar, o que lê e escreve, e um exemplo
trabalhado.

Para instruções de instalação, veja o [README do repositório](../README.md).

## Invocação

| Host | Sintaxe | Exemplo |
|---|---|---|
| Claude Code | `/my-plan:<skill> <args>` | `/my-plan:plan "adicionar exportação CSV na página de relatórios"` |
| Codex CLI | `$my-plan:<skill> <args>` | `$my-plan:plan "adicionar exportação CSV na página de relatórios"` |
| Antigravity | `/<skill> <args>` — sem prefixo de plugin | `/plan "adicionar exportação CSV na página de relatórios"` |
| Gemini CLI | a skill, pelo nome, no prompt | `com a skill plan: "adicionar exportação CSV na página de relatórios"` |

Toda skill é manual — invocá-la é a única forma sancionada de iniciar
uma; o modelo nunca deve invocar uma skill sozinho. No Claude Code e no
Codex CLI o host impõe isso (`disable-model-invocation` no frontmatter,
`allow_implicit_invocation: false` no sidecar). O Antigravity e o Gemini
CLI não têm campo equivalente e podem oferecer a skill ao modelo por
conta própria — por isso cada corpo carrega uma guarda que manda o
modelo parar quando percebe que a skill carregou sem invocação explícita
sua: nesses dois hosts a garantia é essa declaração, não uma trava do
host, e este guia diz isso em vez de esconder. A exceção deliberada, em
qualquer host, é a cadeia do `implement`: depois de construir a tarefa, o
próprio corpo da skill manda seguir os procedimentos de `review` e
`commit` na mesma invocação — isso não é o modelo decidindo invocar algo;
é o que a sua invocação manual de `implement` já pediu. Todos os hosts
leem exatamente o mesmo corpo de skill; só a forma de invocação muda.

O OpenCode segue sem suporte: tem a mesma lacuna dos hosts Google, sem
demanda que justificasse aceitar por lá o mesmo rebaixamento de garantia.

## Convenções que toda skill segue

Três coisas se repetem nas sete skills, explicadas aqui uma única vez em
vez de em cada seção abaixo:

- **Cegueira declarada.** `review` e `commit` aceitam um
  `--spec docs/brief.md` opcional (`commit` também aceita `--tasks`) para
  limitar contra o que verificam. Quando nenhum é dado ou encontrado, a
  skill não pula essa verificação silenciosamente — ela imprime uma linha
  dizendo isso, tipo `Conformance: not evaluated — no brief or plan
  supplied or found.` `cleanup` tem sua própria variante: imprime `Tool
  coverage: not evaluated` quando o stack não tem ferramenta de código
  morto disponível, e `Entry-point context: not evaluated` quando
  `docs/map.md` não existe. `security` usa a mesma forma para sua própria
  lacuna: `Tool coverage: not evaluated` quando falta `gitleaks` ou a
  ferramenta de auditoria de vulnerabilidade de um stack, e `Entry-point
  context: not evaluated` quando `docs/map.md` não existe.
- **Independência.** `plan`, `implement`, `review`, `commit`, `cleanup` e
  `security` fazem cada uma algo que um revisor novo e não envolvido faria
  melhor do que a sessão que acabou de escrever a coisa. No Claude Code,
  elas despacham um subagent de verdade (`agents/my-plan-reviewer.md` ou
  `agents/my-plan-committer.md`) que não tem nenhuma ferramenta de edição
  de arquivo e não viu o trabalho acontecer — a cadeia do `implement`
  despacha esses mesmos subagents, então a fronteira vale dentro dela
  também. O Codex CLI e o Antigravity não têm mecanismo
  de subagent, então a skill diz claramente quando o próprio contexto dela
  mostra que foi ela quem escreveu o que está julgando, em vez de alegar
  uma independência que não tem — esse é o caso padrão para `plan` e para
  a cadeia do `implement` agora, não uma exceção, já que cada uma roda
  autoria e julgamento na mesma invocação.
- **Nota de encerramento.** Toda skill que muda ou avalia algo termina com
  as mesmas quatro linhas, impressas na conversa e nunca salvas num
  arquivo:
  ```
  Changed: <o que realmente mudou>
  Validated: <o que realmente rodou, ou "not this skill's job">
  Open risks: <o que ficou em aberto, ou "none">
  Suggested next skill: <o que rodar depois, ou "none">
  ```
  Isso é uma sugestão, não uma fila — você pode ignorar e rodar o que
  quiser em seguida.

## Ordem recomendada

```
map → plan → implement (por tarefa: build → review em loop → commit)
```

Nada disso é obrigatório. Cada `/my-plan:implement` fecha a própria
tarefa — construída, revisada até ficar verde, commitada, com baixa no
quadro — e termina apontando a próxima tarefa para você decidir; ele
nunca começa a próxima sozinho. `review` e `commit` continuam existindo
como skills avulsas para quando você quiser rodar qualquer uma isolada —
um `review --repo` periódico, um commit de algo que você editou à mão, ou
o fluxo antigo por inteiro via `implement --solo`. Toda nota de
encerramento sugere o próximo passo, mas nada te impede de pular etapas.

`cleanup` e `security` ficam fora dessa cadeia de propósito: não são um
passo do arco de uma mudança, são varreduras do repositório inteiro, sem
brief e sem tarefa associada. Rode `/my-plan:cleanup` periodicamente,
antes de um release, ou logo depois de um refactor/deleção grande —
quando a chance de sobra ter ficado para trás é maior. Rode
`/my-plan:security` na mesma cadência, ou sempre que uma dependência nova
entrar — diferente do `review`, cujo `security` lens só dispara quando
alguém já está olhando um diff.

---

## `map`

**Escreve ou atualiza `docs/map.md`** — um navegador de repositório
durável e versionado: stack, comandos de validação exatos, limites de
módulo, convenções não óbvias, armadilhas comprovadas. É o documento que
as outras skills checam primeiro, então uma invocação direta de `review`
ou `implement` não parte do zero.

`docs/map.md` é um arquivo comum. `map` escreve nele diretamente mas nunca
commita — leia o diff, edite à mão, apague uma seção que ficou
desatualizada, reverta. A última palavra é sua.

**Uso:**

```
/my-plan:map                # escreve pela primeira vez, ou reverifica tudo
/my-plan:map refresh        # igual a vazio — reverificação explícita
/my-plan:map auth           # restringe a uma área; as outras seções ficam intactas
```

**Lê:** manifestos de pacote e lockfiles, configuração de CI, docs
canônicos já existentes, configuração de teste, `git log` atrás de padrões
de armadilha recorrente.

**Escreve:** só `docs/map.md`.

**Exemplo.** Num repositório Django + React sem `docs/map.md` ainda:

```
/my-plan:map
```

produz algo assim:

```markdown
# reports-service: Map

## Stack
Python 3.12 / Django 5, React 18 + Vite. Gerenciador de pacote: uv (Python), pnpm (JS).

## Validation
`uv run pytest` — testes de backend, CI: .github/workflows/ci.yml:12
`pnpm test` — testes unitários de frontend, package.json:"scripts"."test"
`pnpm build` — precisa passar antes de qualquer PR de frontend ser mesclado

## Module boundaries
`reports/exporters/` nunca importa de `reports/views/` — exporters são
chamados pelas views, não o contrário. Quebrar isso criou um import
circular duas vezes (ver git log em reports/exporters/csv.py).

## Conventions that aren't obvious from the code
Todo campo monetário é centavo inteiro, nunca float — ver reports/models.py:41.

## Pitfalls
`reports/tasks.py` roda no Celery sem contexto de request — código movido
de uma view para uma task já quebrou por falta de `request.user` três
vezes.
```

Rode `/my-plan:map refresh` mais tarde, quando o stack ou as convenções
mudarem; a skill trata o arquivo existente como uma afirmação a verificar,
não um rascunho a sobrescrever, e preserva o que você editou à mão.

---

## `plan`

**Entrevista você até um `docs/brief.md` decisão-completo, transforma em
`docs/plan.md` mais um arquivo por tarefa, e despacha uma revisão
independente do plano antes de tratá-lo como aprovado** — uma invocação
só, no lugar do que antes eram três skills separadas (`spec`, `plan`,
`review-plan`). A entrevista pergunta em lotes por rodada — a "frontier"
inteira de uma vez, cada pergunta numerada globalmente com uma
recomendação marcada — em vez de uma pergunta isolada de cada vez, mas
mantém o mesmo orçamento de ~10 perguntas no total e a mesma disciplina de
nunca perguntar o que o repositório já responde sozinho.

**Uso:**

```
/my-plan:plan "adicionar exportação CSV na página de relatórios"   # objetivo novo — roda a entrevista
/my-plan:plan docs/brief.md                          # brief já existe — pula direto pro planejamento
/my-plan:plan docs/plan.md                            # plano já existe — modo só-revisão, nada é escrito
/my-plan:plan                                         # sem argumento — usa docs/brief.md se existir, senão pede um objetivo
```

**Lê:** `docs/map.md` se existir; a web, só quando o repositório não
consegue resolver uma questão de negócio ou domínio; `knowledge/checklists/architecture.md`
pelas cinco perguntas que qualquer camada ou abstração nova precisa
responder, tanto ao planejar quanto ao revisar.

**Escreve:** `docs/brief.md` (objetivo novo), `docs/plan.md` e
`docs/tasks/01-*.md`, `docs/tasks/02-*.md` etc. — com zero à esquerda, na
ordem de dependência. No modo só-revisão (argumento aponta pra um plano
existente), nada é escrito.

**Exemplo de sessão** (resumido — mostra uma rodada da entrevista, depois
os dois passos seguintes já resolvidos):

```
> /my-plan:plan "adicionar exportação CSV na página de relatórios"

Li docs/map.md. A página de relatórios é reports/views.py:ReportListView,
renderiza uma tabela paginada no servidor.

Rodada 1 (2 perguntas — frontier inteira, sem dependência entre elas):

Q1 [Escopo]: Exportar a visão atual filtrada/ordenada, ou sempre todas as
linhas?
  a) Visão atual (respeita filtros, ordenação, busca) — recomendado: casa
     com o modelo mental do usuário de "exportar o que estou vendo"
  b) Sempre todas as linhas, ignorando filtros
  → visão atual

Q2 [Limite de linhas]: Limitar o tamanho da exportação?
  a) Sem limite — recomendado: relatórios raramente passam de poucos
     milhares de linhas aqui
  b) Limitar a N linhas com um aviso
  → sem limite

[... mais uma rodada, a frontier esvazia ...]

Nada mais a perguntar. Decisões tomadas sem perguntar: colunas de data
exportam em ISO 8601, não no formato localizado da UI (reversível, prática
padrão).

docs/brief.md escrito. Continuando para o planejamento.

docs/plan.md e 4 arquivos em docs/tasks/ escritos:
docs/tasks/01-csv-serializer.md    — novo reports/exporters/csv.py, sem deps
docs/tasks/02-export-endpoint.md   — nova view + rota de URL, depende de 01
docs/tasks/03-export-button.md     — botão de frontend + chamada fetch, depende de 02
docs/tasks/04-export-tests.md      — teste de integração, depende de 02 e 03

Despachando revisão independente...

Report: docs/plan.md

Findings:
docs/tasks/02-export-endpoint.md:—  major  executability  Nenhum caminho
  de falha declarado para um relatório com zero linhas. Adicionar: "um
  resultado vazio exporta um CSV só com cabeçalho, não um 404."

Lens coverage: conformance passed, correctness passed (1 finding above),
tests passed, complexity passed.

1 finding: 0 blocker, 1 major.

Changed: docs/brief.md, docs/plan.md, and 4 files under docs/tasks/ written
Validated: not this skill's job
Open risks: 1 major
Suggested next skill: fix the findings (by hand, or by re-running this
  skill against the plan) and re-run — or implement, if there are zero
  blockers
```

O brief tem critérios de aceite testáveis do tipo *"Dado uma visão de
relatório filtrada, quando o usuário clica em Exportar CSV, então o
arquivo baixado contém exatamente as linhas filtradas em formato de data
ISO 8601."* — preciso o suficiente para o `review` depois achar o teste
que falharia se isso quebrasse. Corrija o achado (à mão, ou rodando
`plan` de novo contra o plano com a lacuna em mente) e rode de novo até
ficar limpo.

---

## `implement`

**Constrói exatamente uma tarefa e a leva até o histórico na mesma
invocação**: build, revisão independente, loop de correção até a revisão
voltar verde, e o commit — com baixa no quadro de tarefas e entrada de
changelog rascunhada sem perguntar, quando o repositório já mantém um. A
fase de build continua não julgando o próprio trabalho: a revisão
encadeada é um despacho novo no Claude Code (e uma autodeclaração honesta
no Codex CLI), exatamente como o `review` define. Cada fase da cadeia
segue o corpo da skill irmã ao pé da letra — não existe uma segunda cópia
do procedimento de revisão ou de commit para divergir.

**Uso:**

```
/my-plan:implement docs/tasks/01-csv-serializer.md
/my-plan:implement "corrigir o erro de digitação no rótulo do botão de exportar"   # sem precisar de quadro de tarefas
/my-plan:implement docs/tasks/01-csv-serializer.md --solo   # só o build — revisão e commit ficam para você
```

**Lê:** só o arquivo de tarefa nomeado (nunca o plano ou as outras tarefas
— isso é proposital, para não se apoiar acidentalmente em contexto que um
escritor de verdade não teria), `docs/map.md`,
`knowledge/checklists/implementation.md` pelas partes que a superfície da
tarefa realmente toca; depois, na cadeia, os corpos de `review` e
`commit`.

**Escreve:** o que o write set da tarefa nomear durante o build e o loop;
depois, o(s) commit(s), pela fase de commit da cadeia — nunca inline, só
pelos passos do próprio `commit` (escaneamento de segredos, stage
explícito, verificação pós-commit, baixa da tarefa).

**A trava, o loop e o limite:** o commit só acontece numa rodada de
revisão sem nenhum achado `blocker` — e commita exatamente a árvore que
essa rodada revisou: rodada verde nunca é seguida de mais edição, e os
`major`s e `minor`s dela viram riscos em aberto na nota de encerramento,
nunca uma correção silenciosa pós-revisão. Rodada com blocker volta pro
build: corrige um por um sob a disciplina do `--fix` do `review`, e
despacha uma rodada de revisão nova e completa — enquanto a rodada está
vermelha, um `major` cuja correção cabe no write set da tarefa também
pode ser corrigido, porque a rodada nova re-revisa tudo. Um blocker cuja
correção está fora do write set para a cadeia na hora, vermelho e
reportado — trabalho fora do write set é trabalho que ninguém pediu. Três
rodadas é o limite — ainda vermelho na terceira, a cadeia para, reporta e
não commita: um loop que não convergiu até aí está dizendo que o problema
é a tarefa, não o código, e essa decisão é sua. Um `minor` é reportado,
nunca perseguido. E a cadeia nunca começa a tarefa seguinte — ela nomeia
a próxima e para.

**Exemplo:**

```
> /my-plan:implement docs/tasks/01-csv-serializer.md

Escrevi reports/exporters/csv.py: to_csv(queryset) usando csv.writer,
datas em ISO 8601. Adicionei tests/exporters/test_csv.py: queryset vazio,
uma linha, caracteres especiais que exigem aspas.

Rodei: uv run pytest tests/exporters/test_csv.py — 4 passaram

Despachando revisão independente (rodada 1)...

Ran: uv run pytest — 141 passed, 1 failed
Ran: pnpm test — 38 passed

Findings:
`uv run pytest` (exit 1)  blocker  executed  tests  test_reports_index
  quebrou: to_csv consome o queryset que a view reutiliza. Materializar
  com list() antes de iterar.

Corrigindo o blocker... uv run pytest — 142 passed (exit 0).

Despachando revisão independente (rodada 2)... 0 blocker, 1 minor.

Verde. Seguindo para o commit.

CHANGELOG.md existe — entrada rascunhada sem perguntar (--changelog):
- Relatórios agora podem ser exportados para CSV.

Staged: reports/exporters/csv.py, tests/exporters/test_csv.py, CHANGELOG.md
Secret scan: clean
Committed: a1b2c3d "Add CSV export serializer for reports"
Deleted: docs/tasks/01-csv-serializer.md (trabalho verificado no histórico)

Changed: reports/exporters/csv.py, tests/exporters/test_csv.py,
  CHANGELOG.md — a1b2c3d "Add CSV export serializer for reports"
Validated: rodada 1 — uv run pytest (exit 1), pnpm test (exit 0);
  rodada 2 — uv run pytest (exit 0), pnpm test (exit 0). 2 rodadas.
Open risks: 1 minor aceito no commit (número mágico em csv.py:18)
Suggested next skill: implement docs/tasks/02-export-endpoint.md — a
  cadeia nunca começa a próxima; o quadro e o push são seus
```

Com `--solo`, o exemplo para no "Rodei: ..." e a nota de encerramento
volta a sugerir `review` e `commit --tasks` manuais — o arquivo da tarefa
fica onde está, porque quem apaga é o `commit --tasks`, quando o trabalho
realmente entra no histórico. "Implementado mas nunca commitado" ainda
não é feito.

---

## `review`

**Revisa um diff, uma branch, um caminho ou o repositório inteiro**
(`--repo`) contra o checklist de onze lentes (conformance, correctness,
security, maintainability, tests, performance, behavior, design,
accessibility, ux, complexity), **e roda ela mesma, de forma independente,
os comandos reais de validação do repositório** — nunca confia num
relatório de "os testes passam" de quem acabou de escrever o código.
Uma invocação só, no lugar do que antes eram duas skills separadas
(`review` e `validate`). A passada de execução sempre roda primeiro, em
isolamento, e a passada de leitura vem depois — onde uma lente de leitura
toca código que a execução já verificou, ela cita esse resultado real, em
vez de dar sua própria impressão. Só achados com evidência — uma alegação
sem caminho e intervalo de linha, ou sem a saída real de um comando, não é
reportável.

**Uso:**

```
/my-plan:review                          # o diff atual (git diff HEAD + não rastreados)
/my-plan:review feature/csv-export        # uma branch, contra seu merge-base
/my-plan:review reports/exporters/        # um caminho
/my-plan:review --repo                    # o repositório inteiro, sem diff pra seguir
/my-plan:review --spec docs/brief.md      # checa conformidade e critérios de aceite contra um brief
/my-plan:review --fix                     # corrige os achados depois de reportá-los
```

A passada de execução sempre roda o conjunto completo de comandos de
validação do repositório, qualquer que seja o escopo da passada de
leitura — um diff de um arquivo pode quebrar um teste que o diff nem
toca.

**Lê:** `knowledge/checklists/review.md` sempre; a seção Validation de
`docs/map.md` primeiro para achar os comandos, depois CI, depois scripts
de pacote; até dois guias de `knowledge/references/` (o stack do
repositório, mais a preocupação transversal que se aplicar); no modo
`--repo`, também `knowledge/checklists/architecture.md` e
`implementation.md`; os critérios de aceite do brief, se um for nomeado
ou encontrado.

**Escreve:** nada rastreado — a passada de execução verifica
explicitamente que deixou a árvore do jeito que encontrou. Com `--fix`,
exatamente os achados que acabou de reportar, um de cada vez; um achado
apoiado em execução real só é reverificado rodando o mesmo comando de
novo, nunca relendo o código e supondo que passa agora.

**Exemplo:**

```
> /my-plan:review --spec docs/brief.md

Ran: uv run pytest — 142 passed, 0 failed
Ran: pnpm test — 38 passed, 0 failed
Ran: pnpm build — exit 0

Report: working diff (4 files)

Findings:
reports/exporters/csv.py:18  minor  read  maintainability  Número mágico
  8192 para o tamanho do chunk. Dê um nome: CSV_CHUNK_SIZE.

Acceptance criteria checked:
"A exportação filtrada contém exatamente as linhas filtradas" — exercitado
  por tests/exporters/test_csv.py::test_respects_filters — passou.

Lens coverage: conformance passed (executed + read), correctness passed
(executed + read), security passed (read), maintainability passed (1
finding, read), tests passed (executed + read), performance passed
(read), behavior passed (read), design not-applicable (no UI surface in
this diff), accessibility not-applicable, ux passed (read), complexity
passed (read).

1 finding: 0 blocker, 0 major, 1 minor, 0 note.

Changed: none — read-only
Validated: uv run pytest (exit 0), pnpm test (exit 0), pnpm build (exit 0)
Tree: clean — nothing left dirty
Open risks: none
Suggested next skill: commit
```

Um comando que passou uma vez e falhou numa repetição é reportado como um
achado de instabilidade, não silenciosamente repetido até dar verde.

---

## `commit`

**Faz stage exatamente dos caminhos pretendidos, escaneia atrás de
segredos vazados em código e prosa, commita no estilo de mensagem do
próprio repositório, e rascunha uma entrada de changelog quando o
repositório já mantém um e a mudança é visível pro usuário.** Nunca dá
push, nunca força, nunca `--no-verify`, nunca reescreve histórico. Não
existe skill de push — essa é a que te leva até a borda de "sai da
máquina", e para ali.

**Uso:**

```
/my-plan:commit reports/exporters/csv.py reports/views.py
/my-plan:commit --spec docs/brief.md              # limitado pelo write set do brief
/my-plan:commit --tasks docs/tasks/01-csv-serializer.md   # limitado por uma tarefa, apaga ela quando verificada
/my-plan:commit --tasks docs/tasks/01-csv-serializer.md --changelog   # rascunha a entrada sem perguntar
/my-plan:commit                                   # commita o que está sujo — pergunta antes
```

**Lê:** o conteúdo atual de verdade de todo caminho candidato — incluindo
arquivos novos não rastreados, e prosa (uma credencial colada numa nota em
markdown é um vazamento que o escaneamento só-de-código não pega);
`CHANGELOG.md`/`CHANGES.md`/`HISTORY.md` (raiz, depois `docs/`), se algum
existir, para casar o formato da entrada nova com o que o arquivo já usa.

**Escreve:** o(s) commit(s), mais a entrada de changelog quando aplicável
(automática só quando `--spec` ou `--tasks` foi passado explicitamente e
seu write set já previa a entrada, ou quando `--changelog` autorizou de
antemão — é a flag que a cadeia do `implement` passa; um brief encontrado
implicitamente nunca autoriza sozinho — pergunta uma vez, mostrando a
entrada, antes de incluir). `--changelog` só dispensa a pergunta: um
changelog que não existe continua não sendo criado. Apaga o arquivo de
tarefa nomeado assim que o trabalho dele é verificado dentro do(s)
novo(s) commit(s), se `--tasks` foi dado.

**Exemplo:**

```
> /my-plan:commit --tasks docs/tasks/01-csv-serializer.md

CHANGELOG.md existe. O write set da tarefa já previa essa entrada — vou
adicionar automaticamente:

## [Unreleased]
### Added
- Relatórios agora podem ser exportados para CSV, respeitando os filtros
  e a ordenação aplicados na tela.

Staged: reports/exporters/csv.py, tests/exporters/test_csv.py, CHANGELOG.md
Secret scan: clean
Committed: a1b2c3d "Add CSV export serializer for reports"
Verified: git diff-tree confirms exactly those 3 paths in the new commit;
  refs/remotes and refs/tags unchanged
Deleted: docs/tasks/01-csv-serializer.md (work now in history)

Changed: a1b2c3d "Add CSV export serializer for reports"
Validated: assumed green from the prior review — tree unchanged since
Open risks: none
Suggested next skill: none — run this yourself:
  git push origin feature/csv-export
```

Se o escaneamento de segredos ou a verificação pós-commit acharem algo
errado, o `commit` para e reporta — ele nunca descarta um caminho
silenciosamente e commita o resto, e nunca conserta um commit ruim
sozinho. Ele te diz o comando exato para desfazer você mesmo.

---

## `cleanup`

**Varre o repositório inteiro (ou um caminho) atrás de código morto,
dependências não usadas, resíduos de build e deriva entre documentação/
config e a realidade do repositório** — usando as ferramentas do próprio
stack quando existem (Knip, Vulture, staticcheck, cargo-machete...).
Diferente das outras seis, não é um passo do arco de uma mudança: é uma
faxina periódica, independente. Report-only por padrão; `--fix` remove
achados de alta confiança um de cada vez e nunca reorganiza estrutura
sozinha.

**Uso:**

```
/my-plan:cleanup                              # varredura completa, só relatório
/my-plan:cleanup reports/                     # restringe a um caminho
/my-plan:cleanup --fix                        # remove achados confirmados, um por vez
/my-plan:cleanup --rename OldName NewName     # renomeação segura (opt-in)
/my-plan:cleanup --simplify reports/          # simplificação comportamento-preservando (opt-in)
/my-plan:cleanup --extract reports/views.py:120-180   # extração de função comportamento-preservando (opt-in)
```

**Lê:** `knowledge/checklists/cleanup.md` sempre; `cleanup-code.md`,
`cleanup-residue.md` e `cleanup-docs.md` numa varredura padrão;
`knowledge/checklists/architecture.md` também para achados estruturais;
`cleanup-refactor.md` só quando `--simplify`/`--rename`/`--extract` for
dado; `docs/map.md` se existir.

**Escreve:** nada, a não ser que `--fix` (ou uma flag de refatoração)
tenha sido dado — aí exatamente os itens confirmados, um de cada vez,
revalidando a suíte de testes depois de cada um.

**Exemplo:**

```
> /my-plan:cleanup

Report: repositório inteiro

Findings:
reports/exporters/legacy_csv.py:—  minor  high  dead-code  Nenhuma
  referência em código, CI, scripts ou docs — substituído por
  reports/exporters/csv.py em a1b2c3d. Remover o arquivo inteiro.
package.json:—  minor  high  unused-deps  `moment` ainda listado; nenhum
  import restante depois da migração para date-fns. Remover a dependência.
CLAUDE.md:12  major  high  doc-drift  Cita `npm run legacy-export`, um
  script que não existe mais em package.json. Corrigir ou remover a linha.

Category coverage: dead-code found 1, unused-deps found 1, residue
passed, doc-drift found 1, structure passed.

3 findings: 0 blocker, 1 major, 2 minor. Todos de alta confiança.

Changed: none — read-only
Validated: not this skill's job
Open risks: 3 (nenhum removido ainda — rode com --fix para aplicar)
Suggested next skill: plan, for any structural finding — or review, then
  commit, for anything --fix touched
```

Rodar `/my-plan:cleanup --fix` em seguida remove os itens de alta
confiança um de cada vez, revalidando depois de cada remoção, e reverte
só aquele item se algo quebrar — nunca em lote.

---

## `security`

**Audita o repositório inteiro (ou um caminho) atrás de segredos vazados
— working tree *e* histórico do Git —, dependências vulneráveis e risco
de código/configuração categorizado por OWASP/CWE.** Diferente de
`review`, cuja lente `security` só dispara sobre um diff que alguém já
está olhando, esta skill roda sem esperar por nenhuma mudança em
andamento. Sempre report-only: não existe `--fix` para `security`, em
nenhuma categoria — rotacionar uma credencial, atualizar uma dependência
vulnerável ou escrever um header de segurança fica para você, para o
`plan`, ou para o comando do próprio gerenciador de pacotes.

**Uso:**

```
/my-plan:security                # varredura completa do repositório
/my-plan:security reports/       # restringe a um caminho
```

**Lê:** `knowledge/checklists/security.md` sempre;
`secrets-patterns.md`, `security-secrets.md`, `security-deps.md`,
`security-code.md` e `security-config.md` — as mesmas quatro categorias em
toda invocação, já que segredo, dependência e configuração não são
conceitos com forma de diff; `knowledge/checklists/review.md` (lente
`security`) e `knowledge/references/security-review-guide.md` como
profundidade da categoria de código; `docs/map.md` se existir.

**Escreve:** nada. Nunca — não existe `--fix` nesta skill, em nenhuma
categoria, em nenhuma invocação.

**Exemplo:**

```
> /my-plan:security

Report: repositório inteiro

Findings:
config/settings.py:34  blocker  high  secrets  Chave AWS real
  (AKIA...9F2X) commitada em texto puro. Rotacionar a credencial na AWS
  primeiro; depois remover a linha.
package.json:—  major  high  deps  `axios@0.21.1` — CVE-2021-3749 (ReDoS),
  patch disponível em 0.21.4, dependência direta. Bump direto no
  manifesto. [OWASP-A06]
reports/views.py:88  major  medium  code  Endpoint retorna o relatório de
  qualquer `report_id` sem checar `request.user` contra o dono —
  filtrar a query por `owner=request.user`. [OWASP-A01, CWE-862]
—  minor  high  config  Nenhum `Content-Security-Policy` configurado; a
  aplicação renderiza HTML gerado a partir de campos de texto do usuário.
  Adicionar uma CSP restritiva no middleware de segurança já usado para
  os outros headers.

Category coverage: secrets found 1, deps found 1, code found 1, config
found 1.

4 findings: 1 blocker, 3 major, 0 minor, 0 note.

Changed: none — read-only, always
Validated: not this skill's job
Open risks: 1 blocker
Suggested next skill: plan, for the access-control and CSP findings — the
  dependency bump, run yourself — then review and commit. For a
  credencial vazada: rotacione primeiro, antes de qualquer outra coisa.
```

Nenhum valor real de segredo aparece no relatório — só os 4 primeiros
caracteres seguidos de reticências, por `secrets-patterns.md`.

---

## Um passo a passo completo

Adicionando exportação CSV do zero até o push:

```
/my-plan:map                                          # uma vez por repo, ou quando desatualizar
/my-plan:plan "adicionar exportação CSV na página de relatórios"   # entrevista → brief → plano → revisão independente
                                                        # corrija os achados, rode de novo até limpar
/my-plan:implement docs/tasks/01-csv-serializer.md     # cada invocação: build → review em loop → commit + baixa
/my-plan:implement docs/tasks/02-export-endpoint.md    #   — a nota de encerramento aponta a próxima; você invoca
/my-plan:implement docs/tasks/03-export-button.md
/my-plan:implement docs/tasks/04-export-tests.md
/my-plan:review --spec docs/brief.md                   # opcional: a feature inteira contra o brief, de ponta a ponta
git push origin feature/csv-export                     # sua decisão, sempre
```

Um fix de uma linha é uma invocação só: `/my-plan:implement "corrigir o
erro de digitação no rótulo do botão de exportar"` já constrói, revisa e
commita — falta só o push, que continua seu. Prefere o fluxo em etapas?
`--solo` no `implement` e depois `review` e `commit` manuais, como sempre
foi.
