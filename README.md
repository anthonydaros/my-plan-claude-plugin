# My Plan

**Sete skills afiadas e independentes — cinco para o arco de uma mudança,
duas para varreduras periódicas do repositório inteiro — sem orquestração
entre invocações, sem máquina de estados, sem runtime instalado no seu
repositório.**

`map` · `plan` · `implement` · `review` · `commit` · `cleanup` · `security`

Cada skill é invocada manualmente, faz um único trabalho, imprime uma nota
de encerramento e para. Nenhuma invocação puxa a próxima — a única cadeia
sancionada vive dentro do `implement`, que constrói uma tarefa e, na mesma
invocação, a leva por revisão independente e loop de correção até um
commit com baixa no quadro (`--solo` desliga a cadeia). O sistema de
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

### Antigravity / Gemini CLI (Google)

Clone o repositório uma vez — cada skill referencia `knowledge/` por
caminho relativo, então a árvore do plugin precisa continuar inteira no
disco. Instalar por cópia de pasta isolada quebra essas referências
(verificado com uma instalação real, não suposto); as formas abaixo
preservam a árvore:

```bash
git clone https://github.com/anthonydaros/my-plan-claude-plugin.git
cd my-plan-claude-plugin
```

**Antigravity CLI (`agy`)** — instala a árvore inteira como plugin:

```bash
agy plugin install ./plugin
```

**Gemini CLI (0.46+)** — linke cada skill; `gemini skills link` cria um
symlink e as referências `../../knowledge/` resolvem através dele.
(`gemini skills install` copia a pasta isolada e as quebra — não use):

```bash
for s in map plan implement review commit cleanup security; do
  gemini skills link "./plugin/skills/$s" --consent
done
```

**Antigravity IDE** — a mesma regra do symlink, no diretório global de
skills que os produtos Antigravity leem:

```bash
mkdir -p ~/.gemini/config/skills
for s in map plan implement review commit cleanup security; do
  ln -s "$PWD/plugin/skills/$s" ~/.gemini/config/skills/"$s"
done
```

Inicie uma nova sessão depois de instalar ou atualizar para as skills
recarregarem. Uma única árvore de plugin atende todos os hosts — o corpo
de cada skill é lido ao pé da letra por todos; só os manifests mudam.

---

## As sete skills

| Skill | O que faz |
|---|---|
| `map` | Escreve `docs/map.md` — stack, comandos de validação exatos, limites de módulo, armadilhas comprovadas. As skills de planejamento e revisão leem esse arquivo primeiro, quando ele existe. |
| `plan` | Entrevista você até um `docs/brief.md` decisão-completa (rodadas em lote, orçamento de perguntas), transforma o brief em `docs/plan.md` mais um arquivo por tarefa em `docs/tasks/`, e despacha uma revisão independente do plano antes de tratá-lo como aprovado. Uma só invocação faz o que antes eram três skills. |
| `implement` | Constrói exatamente uma tarefa e a leva até o histórico na mesma invocação: revisão independente, loop de correção até ficar verde (três rodadas no máximo), commit com baixa da tarefa e changelog sem perguntar — e termina apontando a próxima tarefa, sem nunca começá-la. `--solo` para depois do build. |
| `review` | Revisa um diff, uma branch, um caminho ou o repositório inteiro (`--repo`) contra um checklist de onze lentes, e roda ela mesma, de forma independente, os comandos reais de validação do repositório — nunca confia num "passou" alegado. Cada achado diz se veio de execução real ou de leitura. |
| `commit` | Stage exatamente dos caminhos pretendidos, escaneia código *e prosa* atrás de segredos, commita no estilo do seu próprio repositório, e rascunha uma entrada de changelog quando o repositório já mantém um. Imprime o comando de push; nunca o executa. |
| `cleanup` | Varre o repositório inteiro (ou um caminho) atrás de código morto, dependências não usadas e deriva entre documentação/meta-config e a realidade do repositório, usando as ferramentas do próprio stack quando existem. Não é um passo do arco de uma mudança — é uma faxina periódica, independente. |
| `security` | Audita o repositório atrás de segredos vazados (working tree *e* histórico do Git), dependências vulneráveis e risco de código/configuração categorizado por OWASP. Sempre só relatório — não existe `--fix` nesta skill, em nenhuma categoria. |

Invoque com `/my-plan:<skill>` no Claude Code, `$my-plan:<skill>` no
Codex CLI, ou `/<skill>` no Antigravity (as skills aparecem sem o prefixo
`my-plan:` lá; no Gemini CLI, peça a skill pelo nome) — por exemplo
`/my-plan:plan "adicionar modo escuro"`, `$my-plan:review --repo` ou
`/review --repo`.

**[Guia completo das skills](plugin/README.md)** — o que cada skill lê e
escreve, exemplos de uso e um passo a passo completo do objetivo até o
commit publicado.

### Combinando as skills

A ordem natural é:

```
map → plan → implement (por tarefa: build → review em loop → commit)
```

Cada `/my-plan:implement` fecha a própria tarefa e termina apontando a
próxima — invocá-la é sempre decisão sua; a cadeia nunca começa a tarefa
seguinte sozinha. Toda nota de encerramento sugere o próximo passo, mas
nada obriga a ordem — `review` e `commit` continuam skills avulsas para
rodar isoladas quando quiser, e `implement --solo` restaura o fluxo em
etapas. Um fix de uma linha é uma invocação só de `implement`; uma
feature de verdade percorre o arco inteiro.

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

A única automação que voltou, de propósito e num único lugar, é a cadeia
dentro do `implement`: revisão, loop de correção e commit da tarefa que
você acabou de mandar construir — sem estado persistente, sem máquina de
fases, limitada a três rodadas de revisão e travada num resultado sem
blocker. Ela não decide nada entre invocações: a próxima tarefa continua
sendo um comando que só você digita.

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
  `implement`, `review`, `commit`, `cleanup` e `security` despacham
  subagents novos e somente-leitura — a cadeia do `implement` despacha
  esses mesmos subagents, então a fronteira vale dentro dela também. No
  Codex CLI e no Antigravity, que não têm um mecanismo de subagent, a
  skill diz claramente quando percebe que foi ela mesma quem escreveu o
  que está julgando, em vez de fingir uma independência que não tem —
  esse é o caso padrão para `plan` e para a cadeia do `implement` agora,
  não uma exceção, já que cada uma roda autoria e julgamento na mesma
  invocação.
- Emendar na tarefa seguinte sozinho. A cadeia do `implement` cobre
  exatamente a tarefa invocada: commit só numa rodada de revisão sem
  blocker, no máximo três rodadas antes de parar e devolver para você, e
  a próxima tarefa é apenas nomeada na nota de encerramento — nunca
  iniciada.
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
  inventa uma seção nova. `--changelog` (a flag que a cadeia do
  `implement` passa) só dispensa a pergunta de confirmação; não muda nada
  disso.

## Requisitos

| Host | Necessário |
|------|----------|
| Claude Code | Claude Code com suporte a plugins, Git 2.28+ |
| Codex CLI | Codex CLI com `exec`, Git 2.28+ |
| Antigravity / Gemini CLI | Antigravity com suporte a skills, ou Gemini CLI 0.46+, Git 2.28+ |

Nada além disso. Nenhum servidor MCP, nenhum LSP, nenhum hook, nenhuma
outra CLI é dependência — só Git e o próprio host.

**Manual-only por host, em três níveis.** No Claude Code é imposto pelo
host, via frontmatter (`disable-model-invocation: true`); no Codex CLI
também, via sidecar (`allow_implicit_invocation: false`). O Antigravity e
o Gemini CLI não têm campo equivalente — lá o nível cai para declaração:
a descrição de cada skill avisa que ela só ativa por invocação explícita,
e o próprio corpo carrega uma guarda que manda o modelo parar se a skill
carregar sem você tê-la chamado. É a garantia mais fraca dos três níveis,
aceita de propósito para alcançar esses hosts, e dita aqui em vez de
escondida. O OpenCode segue sem suporte: tem a mesma lacuna, sem demanda
que justificasse aceitar o mesmo rebaixamento por lá.

## Desinstalar

```bash
/plugin uninstall my-plan@my-plan          # Claude Code
codex plugin remove my-plan@my-plan-codex  # Codex CLI
agy plugin uninstall my-plan               # Antigravity CLI
for s in map plan implement review commit cleanup security; do
  gemini skills uninstall "$s"             # Gemini CLI
  rm -f ~/.gemini/config/skills/"$s"       # Antigravity IDE (remove os links)
done
```

---

## Licença

MIT. Os guias de revisão de terceiros em `plugin/knowledge/references/`
são vendorizados de
[awesome-skills/code-review-skill](https://github.com/awesome-skills/code-review-skill)
sob a própria licença MIT deles — veja
`plugin/knowledge/references/NOTICE.md`.
