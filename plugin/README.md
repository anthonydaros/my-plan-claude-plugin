# My Plan — guia das skills

Nove skills independentes. Cada uma faz um único trabalho, lê e escreve
arquivos comuns dentro de `docs/`, e para. Nada encadeia automaticamente —
você decide o que rodar e quando. Este guia cobre cada skill em detalhe: o
que ela faz, como invocar, o que lê e escreve, e um exemplo trabalhado.

Para instruções de instalação, veja o [README do repositório](../README.md).

## Invocação

| Host | Sintaxe | Exemplo |
|---|---|---|
| Claude Code | `/my-plan:<skill> <args>` | `/my-plan:spec "adicionar exportação CSV na página de relatórios"` |
| Codex CLI | `$my-plan:<skill> <args>` | `$my-plan:spec "adicionar exportação CSV na página de relatórios"` |

Toda skill é manual — digitar o comando é a única forma de iniciar uma;
nenhuma skill invoca outra nem invoca a si mesma automaticamente. Os dois
hosts leem exatamente o mesmo corpo de skill; só o prefixo de invocação
muda.

## Convenções que toda skill segue

Três coisas se repetem nas nove skills, explicadas aqui uma única vez em
vez de em cada seção abaixo:

- **Cegueira declarada.** `review`, `validate` e `commit` aceitam um
  `--spec docs/brief.md` opcional (`commit` também aceita `--tasks`) para
  limitar contra o que verificam. Quando nenhum é dado ou encontrado, a
  skill não pula essa verificação silenciosamente — ela imprime uma linha
  dizendo isso, tipo `Conformance: not evaluated — no brief or plan
  supplied or found.` `cleanup` tem sua própria variante: imprime `Tool
  coverage: not evaluated` quando o stack não tem ferramenta de código
  morto disponível, e `Entry-point context: not evaluated` quando
  `docs/map.md` não existe.
- **Independência.** `review-plan`, `review`, `validate`, `commit` e
  `cleanup` fazem cada uma algo que um revisor novo e não envolvido faria
  melhor do que a
  sessão que acabou de escrever a coisa. No Claude Code, elas despacham um
  subagent de verdade (`agents/my-plan-reviewer.md` ou
  `agents/my-plan-committer.md`) que não tem nenhuma ferramenta de edição
  de arquivo e não viu o trabalho acontecer. O Codex CLI não tem mecanismo
  de subagent, então a skill diz claramente quando o próprio contexto dela
  mostra que foi ela quem escreveu o que está julgando, em vez de alegar
  uma independência que não tem.
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
map → spec → plan → review-plan → implement (por tarefa) → review → validate → commit
```

Nada disso é obrigatório. Rode uma skill isolada para um fix pequeno
(`implement` e depois `commit`), ou percorra a cadeia inteira para uma
feature de verdade. Toda nota de encerramento sugere o próximo passo nessa
ordem, mas nada te impede de pular etapas.

`cleanup` fica fora dessa cadeia de propósito: não é um passo do arco de
uma mudança, é uma varredura do repositório inteiro, sem brief e sem
tarefa associada. Rode `/my-plan:cleanup` periodicamente, antes de um
release, ou logo depois de um refactor/deleção grande — quando a chance
de sobra ter ficado para trás é maior.

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

## `spec`

**Transforma um objetivo vago em `docs/brief.md`** — um brief com decisão
completa, requisitos numerados, não-objetivos, critérios de aceite
testáveis, riscos e um write set esperado. Chega lá perguntando só o que o
repositório genuinamente não consegue responder sozinho, uma pergunta por
vez, limitado a cerca de dez perguntas no total.

**Uso:**

```
/my-plan:spec "adicionar exportação CSV na página de relatórios"
```

**Lê:** `docs/map.md`, se existir (e faz uma versão mais leve dessa mesma
investigação sozinha, se não existir); a web, só quando o repositório não
consegue resolver uma questão de negócio ou domínio.

**Escreve:** só `docs/brief.md`.

**Exemplo de sessão:**

```
> /my-plan:spec "adicionar exportação CSV na página de relatórios"

Li docs/map.md. A página de relatórios é reports/views.py:ReportListView,
renderiza uma tabela paginada no servidor.

P1 [Escopo]: Exportar a visão atual filtrada/ordenada, ou sempre todas as
linhas?
  a) Visão atual (respeita filtros, ordenação, busca) — recomendado: casa
     com o modelo mental do usuário de "exportar o que estou vendo"
  b) Sempre todas as linhas, ignorando filtros
  → visão atual

P2 [Limite de linhas]: Limitar o tamanho da exportação?
  a) Sem limite — recomendado: relatórios raramente passam de poucos
     milhares de linhas aqui
  b) Limitar a N linhas com um aviso
  → sem limite

[... mais algumas rodadas ...]

Nada mais a perguntar. Decisões tomadas sem perguntar: colunas de data
exportam em ISO 8601, não no formato localizado da UI (reversível, prática
padrão).

Changed: docs/brief.md written
Validated: not this skill's job
Open risks: none
Suggested next skill: plan
```

O brief agora tem critérios de aceite testáveis do tipo *"Dado uma visão
de relatório filtrada, quando o usuário clica em Exportar CSV, então o
arquivo baixado contém exatamente as linhas filtradas em formato de data
ISO 8601."* — preciso o suficiente para o `validate` depois achar o teste
que falharia se isso quebrasse.

---

## `plan`

**Transforma o brief em `docs/plan.md` mais um arquivo por tarefa** dentro
de `docs/tasks/`, cada um dimensionado para quem só vai ver aquele único
arquivo — um punhado de arquivos, uma ideia, verificável isoladamente,
completo sem contexto escondido.

**Uso:**

```
/my-plan:plan                       # planeja a partir de docs/brief.md
/my-plan:plan docs/briefs/csv.md    # planeja a partir de um brief específico
/my-plan:plan "só adicionar um endpoint /health"   # planeja sem brief, para trabalho pequeno
```

**Lê:** o brief (o caminho do argumento, ou `docs/brief.md`), `docs/map.md`
se existir, `knowledge/checklists/architecture.md` pelas cinco perguntas
que qualquer camada ou abstração nova precisa responder.

**Escreve:** `docs/plan.md` e `docs/tasks/01-*.md`, `docs/tasks/02-*.md`
etc. — com zero à esquerda, na ordem de dependência, então um `ls
docs/tasks/` simples já lê na ordem de construção.

**Exemplo de saída** (resumido):

```
docs/plan.md          — Approach, write set, execution order
docs/tasks/01-csv-serializer.md    — novo reports/exporters/csv.py, sem deps
docs/tasks/02-export-endpoint.md   — nova view + rota de URL, depende de 01
docs/tasks/03-export-button.md     — botão de frontend + chamada fetch, depende de 02
docs/tasks/04-export-tests.md      — teste de integração, depende de 02 e 03
```

Cada arquivo de tarefa nomeia caminhos exatos, o caminho de falha
(relatório vazio, exportação no meio de uma requisição), e o teste que
prova que está pronta — quem abre só `03-export-button.md` já tem tudo que
precisa.

```
Changed: docs/plan.md and 4 files under docs/tasks/ written
Validated: not this skill's job
Open risks: none
Suggested next skill: review-plan — in Claude Code the dispatch already
  gives you a fresh reviewer; in Codex, open a fresh session first
```

---

## `review-plan`

**Revisa adversarialmente `docs/plan.md`** e seus arquivos de tarefa antes
de qualquer código existir: cobertura de aceite faltando, passos
impossíveis, escopo inseguro, sequenciamento fraco, testes fracos,
overengineering. Uma skill separada de `plan` de propósito — quem revisa o
plano não deveria ser quem o escreveu.

**Uso:**

```
/my-plan:review-plan                  # revisa docs/plan.md
/my-plan:review-plan docs/other.md    # revisa um plano específico
```

**Lê:** o plano, todo arquivo de tarefa que ele lista, o brief contra o
qual foi planejado, `docs/map.md`, `knowledge/checklists/architecture.md`.

**Escreve:** nada — só leitura.

**Exemplo:**

```
> /my-plan:review-plan

Report: docs/plan.md

Findings:
docs/tasks/02-export-endpoint.md:—  major  executability  Nenhum caminho
  de falha declarado para um relatório com zero linhas. Adicionar: "um
  resultado vazio exporta um CSV só com cabeçalho, não um 404."
docs/tasks/04-export-tests.md:—  minor  tests  A seção References omite
  reports/tests/factories.py, que o teste da 03 vai precisar para montar
  relatórios de fixture.

Lens coverage: conformance passed, correctness passed (1 finding above),
tests passed (1 finding above), complexity passed.

2 findings: 0 blocker, 1 major, 1 minor.

Changed: none — read-only
Validated: not this skill's job
Open risks: 1 major
Suggested next skill: fix findings then re-run review-plan, or implement
  if there are zero blockers
```

Corrija os achados (à mão, ou rodando `plan` de novo com as lacunas em
mente), e rode `review-plan` de novo até ficar limpo.

---

## `implement`

**Constrói exatamente uma tarefa**, por completo, e para. Não revisa o
próprio trabalho — isso é trabalho do `review` — e não toca em nada fora
dos caminhos declarados da tarefa.

**Uso:**

```
/my-plan:implement docs/tasks/01-csv-serializer.md
/my-plan:implement "corrigir o erro de digitação no rótulo do botão de exportar"   # sem precisar de quadro de tarefas
```

**Lê:** só o arquivo de tarefa nomeado (nunca o plano ou as outras tarefas
— isso é proposital, para não se apoiar acidentalmente em contexto que um
escritor de verdade não teria), `docs/map.md`,
`knowledge/checklists/implementation.md` pelas partes que a superfície da
tarefa realmente toca.

**Escreve:** o que o write set da tarefa nomear. Nunca faz stage nem
commit — isso é uma skill separada, rodada separadamente.

**Exemplo:**

```
> /my-plan:implement docs/tasks/01-csv-serializer.md

Escrevi reports/exporters/csv.py: to_csv(queryset) usando csv.writer,
datas em ISO 8601. Adicionei tests/exporters/test_csv.py: queryset vazio,
uma linha, caracteres especiais que exigem aspas.

Rodei: uv run pytest tests/exporters/test_csv.py — 4 passaram

Changed: reports/exporters/csv.py, tests/exporters/test_csv.py (arquivos
  novos, verificados contra git status --porcelain)
Validated: uv run pytest tests/exporters/test_csv.py — 4 passed (checagem
  de sanidade só, não substitui /my-plan:validate)
Open risks: none
Suggested next skill: review, then validate, then
  commit --tasks docs/tasks/01-csv-serializer.md — or the next task under
  docs/tasks/, if more remain
```

O arquivo da tarefa fica onde está de propósito — é o `commit --tasks`
quem apaga, quando o trabalho realmente entra no histórico.
"Implementado mas nunca commitado" ainda não é feito.

---

## `review`

**Revisa um diff, uma branch, um caminho ou o repositório inteiro**
(`--repo`) contra o checklist de onze lentes (conformance, correctness,
security, maintainability, tests, performance, behavior, design,
accessibility, ux, complexity). Só achados com evidência — uma alegação
sem caminho e intervalo de linha, ou sem a saída real de um comando, não é
reportável.

**Uso:**

```
/my-plan:review                          # o diff atual (git diff HEAD + não rastreados)
/my-plan:review feature/csv-export        # uma branch, contra seu merge-base
/my-plan:review reports/exporters/        # um caminho
/my-plan:review --repo                    # o repositório inteiro, sem diff pra seguir
/my-plan:review --spec docs/brief.md      # checa conformidade contra um brief específico
/my-plan:review --fix                     # corrige os achados depois de reportá-los
```

**Lê:** `knowledge/checklists/review.md` sempre; `docs/map.md` se existir;
até dois guias de `knowledge/references/` (o stack do repositório, mais a
preocupação transversal que se aplicar); no modo `--repo`, também
`knowledge/checklists/architecture.md` e `implementation.md`.

**Escreve:** nada, a não ser que `--fix` tenha sido dado — aí exatamente os
achados que acabou de reportar, um de cada vez, reverificando cada um
antes do próximo.

**Exemplo:**

```
> /my-plan:review

Report: working diff (4 files)

Findings:
reports/exporters/csv.py:18  minor  maintainability  Número mágico 8192
  para o tamanho do chunk. Dê um nome: CSV_CHUNK_SIZE.

Lens coverage: conformance not-applicable (no brief supplied or found),
correctness passed, security passed, maintainability passed (1 finding),
tests passed, performance passed, behavior passed, design not-applicable
(no UI surface in this diff), accessibility not-applicable, ux passed,
complexity passed.

1 finding: 0 blocker, 0 major, 1 minor, 0 note.

Changed: none — read-only
Validated: not this skill's job
Open risks: none
Suggested next skill: validate, then commit
```

Passar `--spec docs/brief.md` aqui também avaliaria a lente `conformance`
contra os requisitos do brief, em vez de marcá-la como not-applicable.

---

## `validate`

**Executa de forma independente os comandos reais de validação do
repositório** e reporta os códigos de saída reais — nunca confia num
relatório de "os testes passam" de quem acabou de escrever o código.
Também verifica se os critérios de aceite do brief são realmente
exercitados por um comando de verdade, não só se alguma suíte ficou verde.

**Uso:**

```
/my-plan:validate                     # acha os comandos em docs/map.md, CI, ou scripts de pacote
/my-plan:validate --spec docs/brief.md
```

**Lê:** a seção Validation de `docs/map.md` primeiro, depois a
configuração de CI, depois os scripts de pacote, nessa ordem; os critérios
de aceite do brief, se um for nomeado ou encontrado.

**Escreve:** nada rastreado — a skill verifica explicitamente que deixou a
árvore do jeito que encontrou, e reporta se algum comando escreveu num
arquivo rastreado mesmo assim.

**Exemplo:**

```
> /my-plan:validate

Ran: uv run pytest — 142 passed, 0 failed
Ran: pnpm test — 38 passed, 0 failed
Ran: pnpm build — exit 0

Acceptance criteria checked:
"A exportação filtrada contém exatamente as linhas filtradas" — exercitado
  por tests/exporters/test_csv.py::test_respects_filters — passou.

Changed: none — read-only
Validated: uv run pytest (exit 0), pnpm test (exit 0), pnpm build (exit 0)
Tree: clean — nothing left dirty
Open risks: none
Suggested next skill: commit, if everything's green
```

Um comando que passou uma vez e falhou numa repetição é reportado como um
achado de instabilidade, não silenciosamente repetido até dar verde.

---

## `commit`

**Faz stage exatamente dos caminhos pretendidos, escaneia atrás de
segredos vazados em código e prosa, commita no estilo de mensagem do
próprio repositório.** Nunca dá push, nunca força, nunca `--no-verify`,
nunca reescreve histórico. Não existe skill de push — essa é a que te leva
até a borda de "sai da máquina", e para ali.

**Uso:**

```
/my-plan:commit reports/exporters/csv.py reports/views.py
/my-plan:commit --spec docs/brief.md              # limitado pelo write set do brief
/my-plan:commit --tasks docs/tasks/01-csv-serializer.md   # limitado por uma tarefa, apaga ela quando verificada
/my-plan:commit                                   # commita o que está sujo — pergunta antes
```

**Lê:** o conteúdo atual de verdade de todo caminho candidato — incluindo
arquivos novos não rastreados, e prosa (uma credencial colada numa nota em
markdown é um vazamento que o escaneamento só-de-código não pega).

**Escreve:** o(s) commit(s). Apaga o arquivo de tarefa nomeado assim que o
trabalho dele é verificado dentro do(s) novo(s) commit(s), se `--tasks` foi
dado.

**Exemplo:**

```
> /my-plan:commit --tasks docs/tasks/01-csv-serializer.md

Staged: reports/exporters/csv.py, tests/exporters/test_csv.py
Secret scan: clean
Committed: a1b2c3d "Add CSV export serializer for reports"
Verified: git diff-tree confirms exactly those 2 paths in the new commit;
  refs/remotes and refs/tags unchanged
Deleted: docs/tasks/01-csv-serializer.md (work now in history)

Changed: a1b2c3d "Add CSV export serializer for reports"
Validated: assumed green from the prior validate — tree unchanged since
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
Diferente das outras oito, não é um passo do arco de uma mudança: é uma
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
  validate, then commit, for anything --fix touched
```

Rodar `/my-plan:cleanup --fix` em seguida remove os itens de alta
confiança um de cada vez, revalidando depois de cada remoção, e reverte
só aquele item se algo quebrar — nunca em lote.

---

## Um passo a passo completo

Adicionando exportação CSV do zero até o push:

```
/my-plan:map                                          # uma vez por repo, ou quando desatualizar
/my-plan:spec "adicionar exportação CSV na página de relatórios"   # → docs/brief.md
/my-plan:plan                                          # → docs/plan.md + docs/tasks/*.md
/my-plan:review-plan                                   # corrija os achados, rode de novo até limpar
/my-plan:implement docs/tasks/01-csv-serializer.md     # repita por tarefa
/my-plan:implement docs/tasks/02-export-endpoint.md
/my-plan:implement docs/tasks/03-export-button.md
/my-plan:implement docs/tasks/04-export-tests.md
/my-plan:review                                        # contra o diff atual
/my-plan:validate --spec docs/brief.md
/my-plan:commit --spec docs/brief.md                   # um commit ou vários, você decide
git push origin feature/csv-export                     # sua decisão, sempre
```

Um fix de uma linha não precisa da maior parte disso: `/my-plan:implement
"corrigir o erro de digitação no rótulo do botão de exportar"` e depois
`/my-plan:review`, `/my-plan:validate`, `/my-plan:commit` já é um caminho
completo e seguro sozinho.
