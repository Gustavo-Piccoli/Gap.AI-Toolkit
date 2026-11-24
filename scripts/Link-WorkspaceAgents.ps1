<#
.SYNOPSIS
    Vincula repositorios Git de um workspace que possuem CLAUDE.md na raiz ao padrao .agents/AGENTS.md,
    garantindo que ferramentas compativeis com AGENTS.md (como Google Antigravity) leiam o CLAUDE.md do projeto
    sem poluir o git status (via .git/info/exclude).

.PARAMETER WorkspacePath
    Caminho do diretorio de workspace contendo os repositorios Git em suas subpastas imediatas.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$WorkspacePath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $WorkspacePath)) {
    throw "O caminho de workspace informado nao existe: $WorkspacePath"
}

$WorkspacePath = (Resolve-Path -LiteralPath $WorkspacePath).Path
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$bridgeText = "Toda a documentacao de arquitetura, convencoes e regras de comportamento da IA esta centralizada em CLAUDE.md, na raiz do repositorio. Leia CLAUDE.md antes de qualquer analise ou edicao neste projeto."

$subDirs = Get-ChildItem -LiteralPath $WorkspacePath -Directory -ErrorAction SilentlyContinue
$processedCount = 0

foreach ($repoDir in $subDirs) {
    $gitPath = Join-Path $repoDir.FullName ".git"
    $claudeMdPath = Join-Path $repoDir.FullName "CLAUDE.md"

    if (-not ((Test-Path -LiteralPath $gitPath) -and (Test-Path -LiteralPath $claudeMdPath))) {
        continue
    }

    # 1. Cria .agents/AGENTS.md se nao existir
    $agentsDir = Join-Path $repoDir.FullName ".agents"
    $agentsMdPath = Join-Path $agentsDir "AGENTS.md"

    if (-not (Test-Path -LiteralPath $agentsDir)) {
        $null = New-Item -ItemType Directory -Path $agentsDir -Force
    }

    if (-not (Test-Path -LiteralPath $agentsMdPath)) {
        [System.IO.File]::WriteAllText($agentsMdPath, ($bridgeText + [Environment]::NewLine), $utf8NoBom)
        Write-Host "[CRIADO] $agentsMdPath" -ForegroundColor Green
    }
    else {
        Write-Host "[OK]     $agentsMdPath ja existe." -ForegroundColor Gray
    }

    # 2. Garante /.agents/ em .git/info/exclude
    $gitItem = Get-Item -LiteralPath $gitPath -Force
    if ($gitItem.PSIsContainer) {
        $gitInfoDir = Join-Path $gitPath "info"
        if (-not (Test-Path -LiteralPath $gitInfoDir)) {
            $null = New-Item -ItemType Directory -Path $gitInfoDir -Force
        }

        $excludePath = Join-Path $gitInfoDir "exclude"
        $existingContent = ""
        if (Test-Path -LiteralPath $excludePath) {
            $existingContent = [System.IO.File]::ReadAllText($excludePath, [System.Text.Encoding]::UTF8)
        }

        $hasAgentsExclude = $existingContent -match '(?m)^\s*/?\.agents/?\s*$'
        if (-not $hasAgentsExclude) {
            $prefix = ""
            if ($existingContent.Length -gt 0 -and -not $existingContent.EndsWith("`n")) {
                $prefix = [Environment]::NewLine
            }
            $updatedExclude = $existingContent + $prefix + "/.agents/" + [Environment]::NewLine
            [System.IO.File]::WriteAllText($excludePath, $updatedExclude, $utf8NoBom)
            Write-Host "         Adicionado '/.agents/' em $excludePath" -ForegroundColor Cyan
        }
    }

    $processedCount++
}

Write-Host "Concluido: $processedCount repositorio(s) processado(s) em '$WorkspacePath'." -ForegroundColor Cyan
