<#
.SYNOPSIS
    Configura e sincroniza o ambiente global de agentes de IA (Claude Code, Google Antigravity e ~/.agents)
    a partir do repositorio central Gap.AI-Toolkit.

.DESCRIPTION
    Script idempotente compativel com Windows PowerShell 5.1+ que realiza:
      1. Instalacao do Git hook local (.git/hooks/pre-commit) no repositorio Gap.AI-Toolkit.
      2. Remocao segura de skills legadas (gustavo-*) e de Junctions gap-* orfas (destino removido ou renomeado),
         e criacao de Junctions para todas as skills (gap-*) em ~/.claude/skills, ~/.agents/skills e
         ~/.gemini/config/skills.
      3. Geracao do arquivo global ~/.claude/CLAUDE.md importando rules/AGENTS.md e overlays locais/corporativos
         (ex.: ~/.claude/CLAUDE.*.md) quando presentes na maquina.
      4. Sincronizacao do plugin global user-preferences do Google Antigravity (~/.gemini/config/plugins/user-preferences).
      5. Atualizacao cirurgica do servidor MCP review-hub em ~/.gemini/config/mcp_config.json e ~/.claude.json
         em UTF-8 sem BOM, preservando integralmente todas as demais configuracoes existentes.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ToolkitRoot = "",

    [Parameter(Mandatory = $false)]
    [bool]$RemoveLegacyGustavoSkills = $true
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($ToolkitRoot)) {
    $scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Definition }
    $ToolkitRoot = Split-Path -Parent $scriptDir
}
$ToolkitRoot = (Resolve-Path -LiteralPath $ToolkitRoot).Path.TrimEnd('\', '/')
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

Write-Host "=== Gap.AI-Toolkit :: Setup-Environment ===" -ForegroundColor Cyan
Write-Host "ToolkitRoot: $ToolkitRoot" -ForegroundColor Gray

function Remove-DirectoryOrJunctionSafe {
    param(
        [Parameter(Mandatory = $true)]
        [string]$LiteralPath
    )

    if (-not (Test-Path -LiteralPath $LiteralPath)) {
        return
    }

    $item = Get-Item -LiteralPath $LiteralPath -Force
    $isReparsePoint = ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0

    if ($isReparsePoint) {
        $null = & cmd.exe /c "rmdir `"$LiteralPath`"" 2>&1
        if (Test-Path -LiteralPath $LiteralPath) {
            [System.IO.Directory]::Delete($LiteralPath, $false)
        }
    }
    else {
        Remove-Item -LiteralPath $LiteralPath -Recurse -Force
    }
}

function Set-DirectoryJunction {
    param(
        [Parameter(Mandatory = $true)]
        [string]$LinkPath,

        [Parameter(Mandatory = $true)]
        [string]$TargetPath
    )

    $parentDir = Split-Path -Parent $LinkPath
    if (-not (Test-Path -LiteralPath $parentDir)) {
        $null = New-Item -ItemType Directory -Path $parentDir -Force
    }

    if (Test-Path -LiteralPath $LinkPath) {
        Remove-DirectoryOrJunctionSafe -LiteralPath $LinkPath
    }

    $output = & cmd.exe /c "mklink /J `"$LinkPath`" `"$TargetPath`"" 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Falha ao criar Junction '$LinkPath' -> '$TargetPath': $output"
    }
}

function Resolve-PythonExecutable {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$ConfigFiles
    )

    $reviewHubBlockPattern = '(?s)"review-hub"\s*:\s*\{(?:[^{}]|\{[^{}]*\})*\}'
    $commandPattern = '"command"\s*:\s*"([^"]+)"'

    foreach ($file in $ConfigFiles) {
        if (Test-Path -LiteralPath $file) {
            $raw = [System.IO.File]::ReadAllText($file, [System.Text.Encoding]::UTF8)
            $blockMatch = [regex]::Match($raw, $reviewHubBlockPattern)
            if ($blockMatch.Success) {
                $cmdMatch = [regex]::Match($blockMatch.Value, $commandPattern)
                if ($cmdMatch.Success) {
                    $candidate = $cmdMatch.Groups[1].Value -replace '\\\\', '\'
                    if (Test-Path -LiteralPath $candidate) {
                        return $candidate
                    }
                }
            }
        }
    }

    $pyCmd = Get-Command python -ErrorAction SilentlyContinue
    if ($null -ne $pyCmd -and -not [string]::IsNullOrWhiteSpace($pyCmd.Source)) {
        return $pyCmd.Source
    }

    return "python"
}

function Update-ReviewHubMcpInJsonFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$JsonFilePath,

        [Parameter(Mandatory = $true)]
        [string]$PythonExe,

        [Parameter(Mandatory = $true)]
        [string]$ReviewHubScriptPath,

        [Parameter(Mandatory = $false)]
        [switch]$CreateIfMissing
    )

    $pyEscaped = $PythonExe.Replace('\', '\\')
    $scriptEscaped = $ReviewHubScriptPath.Replace('\', '\\')

    if (-not (Test-Path -LiteralPath $JsonFilePath)) {
        if (-not $CreateIfMissing) {
            return $false
        }

        $parentDir = Split-Path -Parent $JsonFilePath
        if (-not (Test-Path -LiteralPath $parentDir)) {
            $null = New-Item -ItemType Directory -Path $parentDir -Force
        }

        $initialJson = @"
{
  "mcpServers": {
    "review-hub": {
      "args": [
        "$scriptEscaped"
      ],
      "command": "$pyEscaped",
      "disabled": false
    }
  }
}
"@
        [System.IO.File]::WriteAllText($JsonFilePath, $initialJson, $utf8NoBom)
        return $true
    }

    $raw = [System.IO.File]::ReadAllText($JsonFilePath, [System.Text.Encoding]::UTF8)
    $blockPattern = '(?s)("review-hub"\s*:\s*\{(?:[^{}]|\{[^{}]*\})*\})'

    if ([regex]::IsMatch($raw, $blockPattern)) {
        $updated = [regex]::Replace($raw, $blockPattern, {
            param($m)
            $block = $m.Value
            $block = [regex]::Replace($block, '("command"\s*:\s*)"[^"]*"', "`${1}`"$pyEscaped`"")
            $block = [regex]::Replace($block, '("args"\s*:\s*\[\s*)"[^"]*"(\s*\])', "`${1}`"$scriptEscaped`"`${2}")
            return $block
        })
    }
    elseif ([regex]::IsMatch($raw, '"mcpServers"\s*:\s*\{')) {
        $insertion = @"
"mcpServers": {
    "review-hub": {
      "command": "$pyEscaped",
      "args": [
        "$scriptEscaped"
      ]
    },
"@
        $updated = [regex]::Replace($raw, '"mcpServers"\s*:\s*\{', $insertion, 1)
    }
    else {
        return $false
    }

    if ($updated -ne $raw) {
        [System.IO.File]::WriteAllText($JsonFilePath, $updated, $utf8NoBom)
    }

    return $true
}

# ---------------------------------------------------------------------------
# 1. Git Hook Local (Gap.AI-Toolkit/.git/hooks/pre-commit)
# ---------------------------------------------------------------------------
$gitDir = Join-Path $ToolkitRoot ".git"
$sourcePreCommit = Join-Path $ToolkitRoot "scripts\hooks\pre-commit"
if ((Test-Path -LiteralPath $gitDir) -and (Test-Path -LiteralPath $sourcePreCommit)) {
    $hooksDir = Join-Path $gitDir "hooks"
    if (-not (Test-Path -LiteralPath $hooksDir)) {
        $null = New-Item -ItemType Directory -Path $hooksDir -Force
    }
    $targetPreCommit = Join-Path $hooksDir "pre-commit"
    Copy-Item -LiteralPath $sourcePreCommit -Destination $targetPreCommit -Force
    Write-Host "[1/5] Git hook pre-commit instalado em: $targetPreCommit" -ForegroundColor Green

    $patternsFile = if ($env:GAP_SENSITIVE_PATTERNS_FILE) { $env:GAP_SENSITIVE_PATTERNS_FILE } else { Join-Path $HOME ".config\gap-toolkit\sensitive-patterns.txt" }
    if (-not (Test-Path -LiteralPath $patternsFile)) {
        Write-Host "      Aviso: arquivo de padroes sensiveis locais ausente ($patternsFile)." -ForegroundColor Yellow
        Write-Host "      Copie scripts\sensitive-patterns.example.txt para esse caminho e preencha com os padroes da sua organizacao." -ForegroundColor Yellow
    }
}
else {
    Write-Host "[1/5] Git hook pre-commit ignorado (.git ou scripts/hooks/pre-commit ausente)." -ForegroundColor Yellow
}

# ---------------------------------------------------------------------------
# 2. Skills (gap-*) via Junctions em ~/.claude/skills, ~/.agents/skills e ~/.gemini/config/skills
# ---------------------------------------------------------------------------
$skillTargetRoots = @(
    (Join-Path $HOME ".claude\skills"),
    (Join-Path $HOME ".agents\skills"),
    (Join-Path $HOME ".gemini\config\skills")
)

foreach ($dir in $skillTargetRoots) {
    if (-not (Test-Path -LiteralPath $dir)) {
        $null = New-Item -ItemType Directory -Path $dir -Force
    }

    if ($RemoveLegacyGustavoSkills) {
        $legacyItems = Get-ChildItem -LiteralPath $dir -Filter "gustavo-*" -Force -ErrorAction SilentlyContinue
        foreach ($legacy in $legacyItems) {
            Remove-DirectoryOrJunctionSafe -LiteralPath $legacy.FullName
            Write-Host "      Skill legada removida: $($legacy.FullName)" -ForegroundColor DarkYellow
        }
    }

    # Remove Junctions gap-* orfas (destino removido ou renomeado no toolkit)
    $gapLinks = @(Get-ChildItem -LiteralPath $dir -Filter "gap-*" -Force -ErrorAction SilentlyContinue |
        Where-Object { ($_.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0 })
    foreach ($gapLink in $gapLinks) {
        # Test-Path no proprio link devolve $true mesmo com destino ausente; testa-se o destino.
        $linkTarget = @($gapLink.Target) | Select-Object -First 1
        if ([string]::IsNullOrWhiteSpace($linkTarget) -or -not (Test-Path -LiteralPath $linkTarget)) {
            Remove-DirectoryOrJunctionSafe -LiteralPath $gapLink.FullName
            Write-Host "      Junction orfa removida: $($gapLink.FullName)" -ForegroundColor DarkYellow
        }
    }
}

$toolkitSkillsDir = Join-Path $ToolkitRoot "skills"
$linkedSkillsCount = 0
if (Test-Path -LiteralPath $toolkitSkillsDir) {
    $gapSkills = Get-ChildItem -LiteralPath $toolkitSkillsDir -Directory -Filter "gap-*" | Sort-Object Name
    foreach ($skill in $gapSkills) {
        foreach ($targetRoot in $skillTargetRoots) {
            $linkPath = Join-Path $targetRoot $skill.Name
            Set-DirectoryJunction -LinkPath $linkPath -TargetPath $skill.FullName
        }
        $linkedSkillsCount++
    }
}
Write-Host "[2/5] $linkedSkillsCount skills 'gap-*' vinculadas via Junction em ~/.claude/skills, ~/.agents/skills e ~/.gemini/config/skills." -ForegroundColor Green

# ---------------------------------------------------------------------------
# 3. Regras Globais do Claude (~/.claude/CLAUDE.md)
# ---------------------------------------------------------------------------
$claudeDir = Join-Path $HOME ".claude"
if (-not (Test-Path -LiteralPath $claudeDir)) {
    $null = New-Item -ItemType Directory -Path $claudeDir -Force
}

$agentsRuleForwardSlash = ((Join-Path $ToolkitRoot "rules\AGENTS.md") -replace '\\', '/')
$claudeMdLines = New-Object System.Collections.Generic.List[string]
$claudeMdLines.Add("# Instrucoes Globais do Usuario")
$claudeMdLines.Add("")
$claudeMdLines.Add("@$agentsRuleForwardSlash")

$overlayFiles = @(
    Get-ChildItem -LiteralPath $claudeDir -Filter "CLAUDE.*.md" -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -ne "CLAUDE.md" -and $_.Name -ne "CLAUDE.template.md" } |
        Sort-Object Name
)

if ($overlayFiles.Count -gt 0) {
    $claudeMdLines.Add("")
    foreach ($overlay in $overlayFiles) {
        $claudeMdLines.Add("@~/.claude/$($overlay.Name)")
    }
}

$claudeMdPath = Join-Path $claudeDir "CLAUDE.md"
$claudeMdContent = ($claudeMdLines -join [Environment]::NewLine) + [Environment]::NewLine
[System.IO.File]::WriteAllText($claudeMdPath, $claudeMdContent, $utf8NoBom)
Write-Host "[3/5] Regras globais do Claude atualizadas em: $claudeMdPath (Overlays: $($overlayFiles.Count))" -ForegroundColor Green

# ---------------------------------------------------------------------------
# 4. Configuracao Global do Google Antigravity (~/.gemini/config)
# ---------------------------------------------------------------------------
$agPluginDir = Join-Path $HOME ".gemini\config\plugins\user-preferences"
$agPluginRulesDir = Join-Path $agPluginDir "rules"
if (-not (Test-Path -LiteralPath $agPluginRulesDir)) {
    $null = New-Item -ItemType Directory -Path $agPluginRulesDir -Force
}

$sourcePluginJson = Join-Path $ToolkitRoot "adapters\antigravity\plugin.json"
$targetPluginJson = Join-Path $agPluginDir "plugin.json"
if (Test-Path -LiteralPath $sourcePluginJson) {
    Copy-Item -LiteralPath $sourcePluginJson -Destination $targetPluginJson -Force
}

$sourceAgentsMd = Join-Path $ToolkitRoot "rules\AGENTS.md"
$targetAgentsMd = Join-Path $agPluginRulesDir "AGENTS.md"
if (Test-Path -LiteralPath $sourceAgentsMd) {
    Copy-Item -LiteralPath $sourceAgentsMd -Destination $targetAgentsMd -Force
}
Write-Host "[4/5] Plugin global 'user-preferences' e rules/AGENTS.md sincronizados no Antigravity." -ForegroundColor Green

# ---------------------------------------------------------------------------
# 5. Registro do MCP review-hub (~/.gemini/config/mcp_config.json e ~/.claude.json)
# ---------------------------------------------------------------------------
$agMcpConfigPath = Join-Path $HOME ".gemini\config\mcp_config.json"
$claudeJsonPath = Join-Path $HOME ".claude.json"
$reviewHubScriptPath = Join-Path $ToolkitRoot "mcp\review-hub\review_hub.py"

$pythonExe = Resolve-PythonExecutable -ConfigFiles @($agMcpConfigPath, $claudeJsonPath)

$agUpdated = Update-ReviewHubMcpInJsonFile `
    -JsonFilePath $agMcpConfigPath `
    -PythonExe $pythonExe `
    -ReviewHubScriptPath $reviewHubScriptPath `
    -CreateIfMissing

$claudeUpdated = Update-ReviewHubMcpInJsonFile `
    -JsonFilePath $claudeJsonPath `
    -PythonExe $pythonExe `
    -ReviewHubScriptPath $reviewHubScriptPath

Write-Host "[5/5] MCP 'review-hub' atualizado (Python: $pythonExe | Antigravity: $agUpdated | Claude: $claudeUpdated)." -ForegroundColor Green
Write-Host "=== Setup concluido com sucesso! ===" -ForegroundColor Cyan
