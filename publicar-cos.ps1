<#
.SYNOPSIS
    Copia o site para a pagina institucional em www.cos.ufrj.br/~heleno.

.DESCRIPTION
    Envia para ~/public_html no servidor o conteudo do ultimo commit (HEAD), sem
    src/ e sem os arquivos de manutencao do repositorio.

    O envio e incremental: o servidor guarda em ~/public_html/.deploy-commit o
    hash do ultimo commit publicado, e so vao os arquivos alterados desde entao.
    Arquivos apagados no repositorio tambem sao apagados no servidor. Se o
    servidor nao tiver esse registro (ou o commit nao existir localmente), o
    site inteiro e enviado.

    Chamado automaticamente pelo publicar.ps1 depois do push. Tambem pode ser
    rodado sozinho, por exemplo depois de um "git pull" de mudancas feitas pela
    interface do GitHub.

    Faz tres conexoes SSH pelo alias "morpheus" do ~/.ssh/config local. Vale
    instalar a chave SSH no servidor (ver README).

.PARAMETER Completo
    Ignora o registro do servidor e envia o site inteiro.

.PARAMETER Desde
    Usa este commit como base, em vez de perguntar ao servidor.

.PARAMETER Simular
    Mostra o que seria enviado e apagado, sem mexer no servidor.

.EXAMPLE
    .\publicar-cos.ps1

.EXAMPLE
    .\publicar-cos.ps1 -Simular
#>
param(
    [switch]$Completo,
    [string]$Desde,
    [switch]$Simular
)

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

$Servidor = 'morpheus'
$Destino  = 'public_html'
$Url      = 'https://www.cos.ufrj.br/~heleno'

# O que existe no repositorio mas nao deve ir para o servidor.
$Excluidos = @(
    'src', 'tmp', 'README.md', 'publicar.ps1', 'publicar-cos.ps1',
    'webgen.config', '.gitignore', '.gitattributes', '.nojekyll'
)

# Acima disso a lista de arquivos nao cabe na linha de comando: envia tudo.
$LimiteIncremental = 300

function Test-Excluido([string]$caminho) {
    foreach ($e in $Excluidos) {
        if ($caminho -eq $e -or $caminho.StartsWith("$e/")) { return $true }
    }
    return $false
}

function Write-Lf([string]$arquivo, [string[]]$linhas) {
    # LF e UTF-8 sem BOM: o arquivo e lido por um shell no Linux.
    $texto = ''
    if ($linhas.Count -gt 0) { $texto = ($linhas -join "`n") + "`n" }
    [IO.File]::WriteAllText($arquivo, $texto, (New-Object Text.UTF8Encoding $false))
}

if (git status --porcelain) {
    Write-Host "Aviso: ha mudancas nao commitadas. So o que esta commitado sera enviado." -ForegroundColor Yellow
}

$head = (git rev-parse HEAD).Trim()
$headCurto = $head.Substring(0, 7)

Write-Host ""
Write-Host "=== COS 1/3  Verificando o que ja esta no servidor ===" -ForegroundColor Cyan
$base = $null
if ($Completo) {
    Write-Host "Envio completo solicitado (-Completo)."
} elseif ($Desde) {
    $base = (git rev-parse $Desde).Trim()
    Write-Host "Base informada: $base"
} else {
    $base = ssh $Servidor "cat ~/$Destino/.deploy-commit 2>/dev/null || true"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Nao foi possivel conectar em $Servidor (exit $LASTEXITCODE)." -ForegroundColor Red
        exit 1
    }
    $base = "$base".Trim()
    if (-not $base) {
        Write-Host "Servidor sem registro de publicacao: vai o site inteiro."
    } else {
        Write-Host "Ultimo commit publicado no COS: $base"
    }
}

if ($base) {
    # Sob ErrorActionPreference=Stop, o 2>$null do PowerShell 5.1 viraria excecao.
    $ErrorActionPreference = 'Continue'
    git cat-file -e "$base^{commit}" 2>$null
    $existe = ($LASTEXITCODE -eq 0)
    $ErrorActionPreference = 'Stop'
    if (-not $existe) {
        Write-Host "Commit $base nao existe localmente (faltou git pull?). Vai o site inteiro." -ForegroundColor Yellow
        $base = $null
    }
}

if ($base -eq $head) {
    Write-Host "COS ja esta atualizado ($headCurto)." -ForegroundColor Green
    exit 0
}

$tmp      = [IO.Path]::GetTempPath()
$pacote   = Join-Path $tmp 'deploy-cos.tar.gz'
$apagados = Join-Path $tmp 'deploy-cos-apagar.txt'
$remover  = @()

if ($base) {
    $alterados = @(git diff --name-only --no-renames --diff-filter=ACMRT $base $head |
        Where-Object { -not (Test-Excluido $_) })
    $remover = @(git diff --name-only --no-renames --diff-filter=D $base $head |
        Where-Object { -not (Test-Excluido $_) })
    if ($alterados.Count -gt $LimiteIncremental) {
        Write-Host "$($alterados.Count) arquivos alterados: mais simples enviar tudo."
        $alterados = $null
    }
} else {
    $alterados = $null
}

Write-Host ""
Write-Host "=== COS 2/3  Montando o pacote ===" -ForegroundColor Cyan
if ($null -eq $alterados) {
    $pathspec = @('.') + ($Excluidos | ForEach-Object { ":(exclude)$_" })
    Write-Host "Enviando o site inteiro (commit $headCurto)."
} else {
    $pathspec = $alterados
    Write-Host "Enviando $($alterados.Count) arquivo(s):"
    $alterados | ForEach-Object { Write-Host "  + $_" }
}
if ($remover.Count -gt 0) {
    Write-Host "Apagando $($remover.Count) arquivo(s) no servidor:" -ForegroundColor Yellow
    $remover | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
}

if ($pathspec.Count -eq 0 -and $remover.Count -eq 0) {
    Write-Host "Nenhum arquivo publicavel mudou; so atualizando o registro no servidor."
}

if ($Simular) {
    Write-Host ""
    Write-Host "Simulacao (-Simular): nada foi enviado." -ForegroundColor Yellow
    exit 0
}

if ($pathspec.Count -gt 0) {
    git archive --format=tar.gz -o $pacote $head -- @pathspec
    if ($LASTEXITCODE -ne 0) {
        Write-Host "git archive falhou (exit $LASTEXITCODE)." -ForegroundColor Red
        exit 1
    }
} else {
    # Pacote vazio, para o passo remoto nao precisar de caso especial.
    git archive --format=tar.gz -o $pacote $head -- .gitignore
}
Write-Lf $apagados $remover

Write-Host ""
Write-Host "=== COS 3/3  Enviando para $Servidor ===" -ForegroundColor Cyan
scp -q $pacote $apagados "${Servidor}:"
if ($LASTEXITCODE -ne 0) {
    Write-Host "scp falhou (exit $LASTEXITCODE). Nada mudou no servidor." -ForegroundColor Red
    exit 1
}

# Extrai, apaga o que saiu do repositorio e so entao grava o novo registro:
# se algo falhar no meio, a proxima execucao reenvia a partir da base antiga.
$remoto = @(
    'set -e'
    "mkdir -p ~/$Destino"
    "cd ~/$Destino"
    'tar xzf ~/deploy-cos.tar.gz --exclude=.gitignore'
    'xargs -r -d ''\n'' rm -f -- < ~/deploy-cos-apagar.txt'
    "echo $head > .deploy-commit"
    'rm -f ~/deploy-cos.tar.gz ~/deploy-cos-apagar.txt'
) -join ' && '
ssh $Servidor $remoto
$codigo = $LASTEXITCODE
Remove-Item $pacote, $apagados -ErrorAction SilentlyContinue
if ($codigo -ne 0) {
    Write-Host "Falha ao extrair no servidor (exit $codigo)." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Publicado no COS ($headCurto):" -ForegroundColor Green
Write-Host "  $Url" -ForegroundColor Green
