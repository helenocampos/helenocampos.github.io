# helenocampos.github.io

Site pessoal de Heleno de Souza Campos Junior, publicado em dois lugares:

- <https://helenocampos.github.io>, via GitHub Pages (este repositorio);
- <https://www.cos.ufrj.br/~heleno>, copia no servidor do PESC/COPPE.

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

O script roda o webgen, mostra o diff, pede confirmacao, commita, faz push e,
em seguida, copia o site para o COS com o `publicar-cos.ps1` (secao abaixo).
Use `-SemPush` para commitar sem publicar, `-Forcar` para pular a confirmacao e
`-SemCOS` para publicar so no GitHub.

Fazendo na mao, e o equivalente a:

```powershell
webgen generate
git add -A
git commit -m "descricao"
git push
```

## Copia no COS (www.cos.ufrj.br/~heleno)

O servidor do COS serve a pasta `~/public_html` da conta. O `publicar-cos.ps1`
mantem essa pasta igual ao ultimo commit do repositorio, conectando pelo alias
SSH `morpheus`. Endereco e usuario do servidor ficam so no `~/.ssh/config` local,
fora do repositorio.

```powershell
.\publicar-cos.ps1            # envia o que mudou desde a ultima copia
.\publicar-cos.ps1 -Simular   # so mostra o que seria enviado/apagado
.\publicar-cos.ps1 -Completo  # reenvia o site inteiro
```

Como funciona:

- O servidor guarda em `~/public_html/.deploy-commit` o hash do ultimo commit
  copiado. O script compara com o `HEAD` local e envia so os arquivos que mudaram
  (via `git archive` + `scp` + `tar`); arquivos apagados no repositorio sao
  apagados la tambem. Sem esse registro, vai o site inteiro.
- Vai **o que esta commitado**, nao a pasta de trabalho. Mudancas feitas pela
  interface do GitHub precisam de `git pull` antes.
- Nao vao para o servidor: `src/`, `tmp/`, `README.md`, os scripts
  `publicar*.ps1`, `webgen.config`, `.gitignore`, `.gitattributes`, `.nojekyll`
  (lista `$Excluidos` no script).
- Os links do site sao todos relativos, por isso funcionam tanto na raiz do
  GitHub Pages quanto em `/~heleno/`. Ao editar o `default.template` ou uma
  pagina, evite links comecando com `/`: no COS eles apontariam para
  `www.cos.ufrj.br/`, fora do site.
- O `.htaccess` (`AddCharset UTF-8 .html`) e ignorado pelo GitHub Pages e serve
  justamente para o Apache do COS.

### Chave SSH (uma vez so)

O script abre tres conexoes SSH. Para nao precisar se autenticar em cada uma,
instale a chave publica no servidor, rodando uma vez no PowerShell:

```powershell
type $env:USERPROFILE\.ssh\id_ed25519.pub | ssh morpheus "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
```

Depois, `ssh morpheus` deve entrar direto.

### Historico: como foi a primeira copia

Em 2026 a copia foi feita na mao: os arquivos publicaveis foram separados numa
pasta local e enviados com `scp -r <pasta> morpheus:~/public_html`. Nessa copia
foi junto o `tmp/webgen.cache`, que pode ser apagado do servidor
(`ssh morpheus rm -r public_html/tmp`).

## Estrutura

| Caminho | O que e |
|---|---|
| `src/` | **Fonte. E o unico lugar que se edita.** |
| `src/default.template` | Layout unico do site: cabecalho, menu lateral, rodape |
| `src/*.page` | Paginas de primeiro nivel (Markdown com front-matter YAML) |
| `src/metainfo` | Regras de copia de arquivos e config de menu dos diretorios |
| `src/images/`, `src/*.css` | Assets |
| `webgen.config` | Config do gerador. `destination` aponta para a raiz do repo. |
| `publicar.ps1` | Script de build + deploy (GitHub e, em seguida, COS) |
| `publicar-cos.ps1` | Copia incremental para o servidor do COS |
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
