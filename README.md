# My Plan

**Oito skills afiadas e independentes para todo o arco de uma mudança —
sem orquestração, sem máquina de estados, sem runtime instalado no seu
repositório.**

`map` · `spec` · `plan` · `review-plan` · `implement` · `review` · `validate` · `commit`

Cada skill é invocada manualmente, faz um único trabalho, imprime uma nota
de encerramento e para. Nada encadeia automaticamente. O sistema de
arquivos é o único estado entre elas — `docs/map.md`, `docs/brief.md`,
`docs/plan.md` e `docs/tasks/*.md` são arquivos comuns: dá pra commitar,
editar, apagar. Rode uma skill isolada, ou percorra o arco inteiro quando a
mudança merecer.

---

## Instalação

### Claude Code

```bash
/plugin marketplace add anthonydaros/my-plan-claude-plugin
/plugin install my-plan@my-plan
```

### Codex CLI

```bash
codex plugin marketplace add anthonydaros/my-plan-claude-plugin
codex plugin add my-plan@my-plan-codex
```

Inicie uma nova sessão depois de instalar ou atualizar para as skills
recarregarem. Uma única árvore de plugin atende os dois hosts — o corpo de
cada skill é lido ao pé da letra por ambos; só os dois manifests mudam.

---

## As oito skills

| Skill | O que faz |
|---|---|
| `map` | Escreve `docs/map.md` — stack, comandos de validação exatos, limites de módulo, armadilhas comprovadas. As skills de planejamento, revisão e validação leem esse arquivo primeiro, quando ele existe. |
| `spec` | Transforma um objetivo vago em `docs/brief.md`: decisão completa, critérios de aceite testáveis, uma rodada limitada de perguntas uma de cada vez. |
| `plan` | Transforma o brief em `docs/plan.md` mais um arquivo por tarefa em `docs/tasks/` — cada um dimensionado para quem só vai ver aquele arquivo. |
| `review-plan` | Ataca o plano antes de qualquer código existir: cobertura faltando, passos impossíveis, escopo inseguro, overengineering. Rode numa sessão nova. |
| `implement` | Constrói exatamente uma tarefa. Deixa o arquivo da tarefa para o `commit` apagar quando o trabalho realmente entrar no histórico. |
| `review` | Revisa um diff, uma branch, um caminho ou o repositório inteiro (`--repo`) contra um checklist de onze lentes. Só achados com evidência. |
| `validate` | Roda de novo, ela mesma, os comandos reais de validação do repositório e reporta os códigos de saída reais — nunca confia num "passou" alegado. |
| `commit` | Stage exatamente dos caminhos pretendidos, escaneia código *e prosa* atrás de segredos, commita no estilo do seu próprio repositório. Imprime o comando de push; nunca o executa. |

Invoque com `/my-plan:<skill>` no Claude Code ou `$my-plan:<skill>` no
Codex CLI — por exemplo `/my-plan:spec "adicionar modo escuro"` ou
`$my-plan:review --repo`.

**[Guia completo das skills](plugin/README.md)** — o que cada skill lê e
escreve, exemplos de uso e um passo a passo completo do objetivo até o
commit publicado.

### Combinando as skills

A ordem natural é:

```
map → spec → plan → review-plan → implement (por tarefa) → review → validate → commit
```

Toda nota de encerramento sugere o próximo passo, mas nada obriga a ordem —
você decide quando rodar cada uma, e pode rodar qualquer uma isoladamente.
Um fix de uma linha pode ser só `implement` seguido de `commit`; uma
feature de verdade pode percorrer a cadeia inteira.

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
- Revisar o próprio trabalho silenciosamente. No Claude Code, `review`,
  `review-plan`, `validate` e `commit` despacham subagents novos e
  somente-leitura. No Codex CLI, que não tem um mecanismo de subagent, a
  skill diz claramente quando percebe que foi ela mesma quem escreveu o
  que está julgando, em vez de fingir uma independência que não tem.

## Requisitos

| Host | Necessário |
|------|----------|
| Claude Code | Claude Code com suporte a plugins, Git 2.28+ |
| Codex CLI | Codex CLI com `exec`, Git 2.28+ |

Nada além disso. Nenhum servidor MCP, nenhum LSP, nenhum hook, nenhuma
outra CLI é dependência — só Git e o próprio host.

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
