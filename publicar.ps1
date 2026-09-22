<#
.SYNOPSIS
    Gera o site com webgen e publica no GitHub Pages.

.DESCRIPTION
    Executa o ciclo completo: webgen generate -> git add -> commit -> push.
    Mostra o que mudou e pede confirmacao antes de commitar.

.PARAMETER Mensagem
    Mensagem do commit. Obrigatoria.

.PARAMETER SemPush
    Commita mas nao faz push. Util para revisar antes de publicar.

.PARAMETER Forcar
    Pula a confirmacao interativa.

.PARAMETER SemCOS
    Publica so no GitHub Pages, sem copiar para www.cos.ufrj.br/~heleno.

.EXAMPLE
    .\publicar.ps1 -m "Atualiza vinculo COPPE/UFRJ"

.EXAMPLE
    .\publicar.ps1 -m "Adiciona disciplina 2026-2" -SemPush
#>
param(
    [Parameter(Mandatory = $true)]
    [Alias('m')]
    [string]$Mensagem,

    [switch]$SemPush,
    [switch]$Forcar,
    [switch]$SemCOS
)

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

Write-Host ""
Write-Host "=== 1/4  Gerando o site com webgen ===" -ForegroundColor Cyan
webgen generate
if ($LASTEXITCODE -ne 0) {
    Write-Host "webgen falhou (exit $LASTEXITCODE). Nada foi commitado." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "=== 2/4  Mudancas detectadas ===" -ForegroundColor Cyan
$mudancas = git status --porcelain
if (-not $mudancas) {
    Write-Host "Nenhuma mudanca. Site ja esta atualizado." -ForegroundColor Green
    exit 0
}

# Deletar arquivo gerado quase sempre e engano: o webgen nunca apaga nada no
# destino, entao uma delecao aqui significa que algo sumiu de src/.
$delecoes = $mudancas | Where-Object { $_ -match '^.D' }
if ($delecoes) {
    Write-Host "ATENCAO - os arquivos abaixo serao APAGADOS do site:" -ForegroundColor Yellow
    $delecoes | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
    Write-Host ""
}
git status --short

if (-not $Forcar) {
    Write-Host ""
    $resposta = Read-Host "Commitar essas mudancas? (s/N)"
    if ($resposta -notmatch '^[sSyY]') {
        Write-Host "Cancelado. Nada foi commitado." -ForegroundColor Yellow
        exit 0
    }
}

Write-Host ""
Write-Host "=== 3/4  Commitando ===" -ForegroundColor Cyan
git add -A
git commit -m $Mensagem
if ($LASTEXITCODE -ne 0) {
    Write-Host "git commit falhou (exit $LASTEXITCODE)." -ForegroundColor Red
    exit 1
}

if ($SemPush) {
    Write-Host ""
    Write-Host "=== 4/4  Push pulado (-SemPush) ===" -ForegroundColor Yellow
    Write-Host "Para publicar depois:  git push" -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "=== 4/4  Publicando ===" -ForegroundColor Cyan
git push
if ($LASTEXITCODE -ne 0) {
    Write-Host "git push falhou (exit $LASTEXITCODE). O commit foi feito localmente." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Publicado. O GitHub Pages leva ate ~1 min para atualizar:" -ForegroundColor Green
Write-Host "  https://helenocampos.github.io" -ForegroundColor Green

if ($SemCOS) {
    Write-Host ""
    Write-Host "Copia para o COS pulada (-SemCOS). Para enviar depois:  .\publicar-cos.ps1" -ForegroundColor Yellow
    exit 0
}

& "$PSScriptRoot\publicar-cos.ps1"
if ($LASTEXITCODE -ne 0) {
    Write-Host "O GitHub foi atualizado, mas a copia no COS falhou. Tente de novo:  .\publicar-cos.ps1" -ForegroundColor Red
    exit 1
}
