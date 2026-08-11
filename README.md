# My Plan

**Sete skills afiadas e independentes — cinco para o arco de uma mudança,
duas para varreduras periódicas do repositório inteiro — sem orquestração,
sem máquina de estados, sem runtime instalado no seu repositório.**

`map` · `plan` · `implement` · `review` · `commit` · `cleanup` · `security`

Cada skill é invocada manualmente, faz um único trabalho, imprime uma nota
de encerramento e para. Nada encadeia automaticamente. O sistema de
arquivos é o único estado entre elas — `docs/map.md`, `docs/brief.md`,
`docs/plan.md` e `docs/tasks/*.md` são arquivos comuns: dá pra commitar,
editar, apagar. Rode uma skill isolada, ou percorra o arco inteiro quando a
mudança merecer.

---

## Instalação

### Claude Code

São dois comandos separados, digitados um de cada vez **na conversa do
Claude Code** (não numa caixa de diálogo, e não colados juntos) — mande o
primeiro, espere confirmar que a marketplace foi adicionada, e só depois
mande o segundo:

```
/plugin marketplace add anthonydaros/my-plan-claude-plugin
```

```
/plugin install my-plan@my-plan
```

Se o Claude Code abrir uma caixa "Add Marketplace" pedindo só a fonte,
cole apenas `anthonydaros/my-plan-claude-plugin` nela — sem o
`/plugin marketplace add` na frente e sem o segundo comando junto.

### Codex CLI

Estes dois já são comandos de terminal de verdade — pode rodar um de cada
vez ou colar o bloco inteiro:

```bash
codex plugin marketplace add anthonydaros/my-plan-claude-plugin
codex plugin add my-plan@my-plan-codex
```

Inicie uma nova sessão depois de instalar ou atualizar para as skills
recarregarem. Uma única árvore de plugin atende os dois hosts — o corpo de
cada skill é lido ao pé da letra por ambos; só os dois manifests mudam.

---

## As sete skills

| Skill | O que faz |
|---|---|
| `map` | Escreve `docs/map.md` — stack, comandos de validação exatos, limites de módulo, armadilhas comprovadas. As skills de planejamento e revisão leem esse arquivo primeiro, quando ele existe. |
| `plan` | Entrevista você até um `docs/brief.md` decisão-completa (rodadas em lote, orçamento de perguntas), transforma o brief em `docs/plan.md` mais um arquivo por tarefa em `docs/tasks/`, e despacha uma revisão independente do plano antes de tratá-lo como aprovado. Uma só invocação faz o que antes eram três skills. |
| `implement` | Constrói exatamente uma tarefa. Deixa o arquivo da tarefa para o `commit` apagar quando o trabalho realmente entrar no histórico. |
| `review` | Revisa um diff, uma branch, um caminho ou o repositório inteiro (`--repo`) contra um checklist de onze lentes, e roda ela mesma, de forma independente, os comandos reais de validação do repositório — nunca confia num "passou" alegado. Cada achado diz se veio de execução real ou de leitura. |
| `commit` | Stage exatamente dos caminhos pretendidos, escaneia código *e prosa* atrás de segredos, commita no estilo do seu próprio repositório, e rascunha uma entrada de changelog quando o repositório já mantém um. Imprime o comando de push; nunca o executa. |
| `cleanup` | Varre o repositório inteiro (ou um caminho) atrás de código morto, dependências não usadas e deriva entre documentação/meta-config e a realidade do repositório, usando as ferramentas do próprio stack quando existem. Não é um passo do arco de uma mudança — é uma faxina periódica, independente. |
| `security` | Audita o repositório atrás de segredos vazados (working tree *e* histórico do Git), dependências vulneráveis e risco de código/configuração categorizado por OWASP. Sempre só relatório — não existe `--fix` nesta skill, em nenhuma categoria. |

Invoque com `/my-plan:<skill>` no Claude Code ou `$my-plan:<skill>` no
Codex CLI — por exemplo `/my-plan:plan "adicionar modo escuro"` ou
`$my-plan:review --repo`.

**[Guia completo das skills](plugin/README.md)** — o que cada skill lê e
escreve, exemplos de uso e um passo a passo completo do objetivo até o
commit publicado.

### Combinando as skills

A ordem natural é:

```
map → plan → implement (por tarefa) → review → commit
```

Toda nota de encerramento sugere o próximo passo, mas nada obriga a ordem —
você decide quando rodar cada uma, e pode rodar qualquer uma isoladamente.
Um fix de uma linha pode ser só `implement` seguido de `commit`; uma
feature de verdade pode percorrer a cadeia inteira.

`cleanup` e `security` ficam fora dessa cadeia de propósito — não são um
passo do arco de uma mudança, são varreduras do repositório inteiro. Rode
`/my-plan:cleanup` periodicamente (a cada poucas semanas, ou antes de um
release), ou logo depois de um refactor ou deleção grande — exatamente
quando a chance de sobra ficar para trás é maior. Rode `/my-plan:security`
na mesma cadência, ou sempre que uma dependência nova entrar no projeto —
ela não espera por um diff em andamento, então nada garante que alguém vá
rodá-la sem essa disciplina.

---

## Por que sem orquestração

Uma versão anterior deste plugin era um único pipeline automático: dois
comandos, um manifesto de Run persistente, um Coordinator despachando
Worker subagents estreitos através de um contrato de handoff em JSON,
worktrees Git isolados, aprovações encadeadas por hash. Funcionava, mas era
muita maquinaria entre o usuário e a coisa que ele realmente queria que
acontecesse — e cada peça dessa maquinaria era algo a entender, confiar e
depurar antes do plugin fazer qualquer coisa útil.

Esta versão mantém as partes que eram garantias de verdade — um revisor
independente, um commit escaneado atrás de segredos, uma execução real de
validação — e descarta tudo que só existia para carregar estado entre
fases que dava para simplesmente... rodar você mesmo, em ordem, quando
decidisse.

## O que ela nunca vai fazer

- **Push.** Não existe skill de push. O `commit` imprime
  `git push <remote> <branch>` e para; você é quem roda.
- `git add -A`, `--force`, `--no-verify`, ou reescrever histórico.
- Commitar uma credencial. Todo caminho candidato é escaneado pelo
  conteúdo antes do stage — incluindo arquivos novos ainda não rastreados
  e prosa em markdown, não só diffs de arquivo rastreado.
- Assinar seus commits. Nenhum `Co-Authored-By`, nenhum nome de modelo, em
  lugar nenhum. O histórico é seu.
- Revisar o próprio trabalho silenciosamente. No Claude Code, `plan`,
  `review`, `commit`, `cleanup` e `security` despacham subagents novos e
  somente-leitura. No Codex CLI, que não tem um mecanismo de subagent, a
  skill diz claramente quando percebe que foi ela mesma quem escreveu o
  que está julgando, em vez de fingir uma independência que não tem —
  esse é o caso padrão para `plan` agora, não uma exceção, já que
  entrevista, planejamento e revisão rodam na mesma invocação.
- Deletar algo que não reportou primeiro. `cleanup` só remove sob um
  `--fix` explícito — cada item confirmado por evidência, um de cada
  vez, revertendo numa validação quebrada (um arquivo não rastreado não
  tem volta e é sinalizado à parte). Reorganização estrutural é sempre
  só relatório — nunca aplicada sozinha.
- Corrigir uma falha de segurança sozinha. `security` não tem `--fix` em
  nenhuma categoria — rotacionar uma credencial, atualizar uma dependência
  vulnerável ou adicionar um header de segurança ficam para você, para o
  `plan`, ou para o comando de upgrade do próprio gerenciador de pacotes.
- Mostrar o valor real de um segredo encontrado. Todo achado de credencial
  aparece mascarado — os 4 primeiros caracteres e reticências — no
  relatório do `commit` e do `security`.
- Confiar numa impressão de leitura em vez de um resultado real. A
  passada de execução do `review` sempre roda primeiro, isolada; um
  achado de leitura que toca código com resultado real já disponível
  cita esse resultado, nunca o rederiva. `--fix` pode tocar um achado de
  execução, mas só reverificando com o mesmo comando rodado de novo.
- Inventar um changelog. `commit` rascunha uma entrada só quando o
  repositório já mantém um (`CHANGELOG.md`/`CHANGES.md`/`HISTORY.md`),
  casando com o formato que o arquivo já usa — nunca cria o arquivo, nunca
  inventa uma seção nova.

## Requisitos

| Host | Necessário |
|------|----------|
| Claude Code | Claude Code com suporte a plugins, Git 2.28+ |
| Codex CLI | Codex CLI com `exec`, Git 2.28+ |

Nada além disso. Nenhum servidor MCP, nenhum LSP, nenhum hook, nenhuma
outra CLI é dependência — só Git e o próprio host.

**Não suporta OpenCode.** O frontmatter de skill do OpenCode não tem
equivalente a `disable-model-invocation`/`allow_implicit_invocation:
false` — o próprio modelo pode invocar uma skill sozinho, sem o usuário
pedir. "Manual only" é a garantia mais repetida deste plugin, checada
pelo smoke test em todas as sete skills; sem um jeito de impor isso,
distribuir para esse host quebraria a própria premissa do projeto.

## Desinstalar

```bash
/plugin uninstall my-plan@my-plan          # Claude Code
codex plugin remove my-plan@my-plan-codex  # Codex CLI
```

---

## Licença

MIT. Os guias de revisão de terceiros em `plugin/knowledge/references/`
são vendorizados de
[awesome-skills/code-review-skill](https://github.com/awesome-skills/code-review-skill)
sob a própria licença MIT deles — veja
`plugin/knowledge/references/NOTICE.md`.
