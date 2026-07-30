# helenocampos.github.io

Site pessoal de Heleno de Souza Campos Junior, publicado em
<https://helenocampos.github.io> via GitHub Pages.

Este repositorio contem **a fonte e o site gerado**. Editar `src/`, rodar o
gerador e commitar: nao existe passo de copia manual entre pastas.

## Pre-requisitos

- **Ruby 3.3+** (testado com 3.3.7)
- **webgen 1.7.3** — `gem install webgen -v 1.7.3`
  (traz o kramdown junto, que e o renderizador de Markdown)

Confira com `ruby -v` e `webgen version`.

## Publicar

```powershell
.\publicar.ps1 -m "descricao do que mudou"
```

O script roda o webgen, mostra o diff, pede confirmacao, commita e faz push.
Use `-SemPush` para commitar sem publicar e `-Forcar` para pular a confirmacao.

Fazendo na mao, e o equivalente a:

```powershell
webgen generate
git add -A
git commit -m "descricao"
git push
```

## Estrutura

| Caminho | O que e |
|---|---|
| `src/` | **Fonte. E o unico lugar que se edita.** |
| `src/default.template` | Layout unico do site: cabecalho, menu lateral, rodape |
| `src/*.page` | Paginas de primeiro nivel (Markdown com front-matter YAML) |
| `src/metainfo` | Regras de copia de arquivos e config de menu dos diretorios |
| `src/images/`, `src/*.css` | Assets |
| `webgen.config` | Config do gerador. `destination` aponta para a raiz do repo. |
| `publicar.ps1` | Script de build + deploy |
| raiz do repo | **Saida gerada.** Nao editar `.html` na raiz: o proximo build sobrescreve. |
| `tmp/` | Cache incremental do webgen (fora do versionamento) |

## Como o site e montado

Cada `.page` e um arquivo Markdown com um bloco YAML no topo:

```yaml
---
title: Talks
in_menu: true
sort_info: 4
---
## Talks

Conteudo em Markdown...
```

O webgen renderiza o Markdown, injeta o resultado no `default.template` (no ponto
do `<webgen:block name="content" />`) e escreve o `.html` correspondente.

**O menu lateral nao existe como arquivo.** Ele e montado automaticamente pela tag
`{menu: ...}` no `default.template`, a partir de todas as paginas que declaram
`in_menu: true`, ordenadas por `sort_info`. Para adicionar um item ao menu, basta
criar a pagina com esses dois campos — nada de editar o template.

> Cuidado com `sort_info` repetido: em caso de empate o desempate e por titulo,
> em ordem alfabetica, o que quase nunca e o que se quer.

Diretorios (como `courses/` e `people/`) recebem titulo, posicao no menu e pagina
de destino pelo bloco `--- alcn` do `src/metainfo`.

## Conteudo copiado sem processamento

O webgen ja copia `.html`, `.css`, `.js`, `.jpg`, `.png`, `.gif` e `.ico` por
padrao. O bloco `--- paths` do `src/metainfo` estende isso para `.pdf`, `.zip`,
`.java`, `.sql` e `.htaccess`.

E por isso que material antigo em HTML puro (`ensino/`, `rito/`,
`complexity_mapping/`, `statistics_mapping/`, `tcp_review_mapping/`,
`speeches.html`) mora em `src/` e e reproduzido tal e qual na saida.

## Notas

- **O webgen nunca apaga arquivos no destino.** Isso torna a publicacao segura,
  mas significa que remover algo de `src/` nao remove da raiz: e preciso apagar o
  arquivo gerado na mao e commitar a delecao. O `publicar.ps1` destaca delecoes em
  amarelo justamente por isso.

  Ha um caso vivo disso: **`courses/2025-2/prog.html`** foi gerado em agosto/2025,
  o `prog.page` correspondente saiu do `src/` depois, e a pagina continua no ar
  com o cabecalho antigo ("Postdoc, IC/UFF"), fora do menu e so alcancavel por
  URL direta. Ou se apaga o arquivo, ou se recria o `.page`.
- `.nojekyll` desliga o processamento pelo Jekyll no GitHub Pages — o site ja vem
  pronto do webgen.
- Como o Pages serve o repositorio inteiro, `src/` tambem fica acessivel na web.
  E fonte publica de um repo publico, entao nao ha nada a esconder.
