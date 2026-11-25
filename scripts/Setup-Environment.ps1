<#
.SYNOPSIS
    Configura e sincroniza o ambiente global de agentes de IA (Claude Code, Google Antigravity e ~/.agents)
    a partir do repositorio central Gap.AI-Toolkit.

.DESCRIPTION
    Script idempotente compativel com Windows PowerShell 5.1+ que realiza:
      1. Instalacao do Git hook local (.git/hooks/pre-commit) no repositorio Gap.AI-Toolkit.
      2. Remocao segura de skills legadas (gustavo-*, so com -RemoveLegacyGustavoSkills $true: Junctions sao
         removidas, pastas reais sao movidas para <raiz>\skills-legacy-backup\<data-hora>) e de Junctions gap-*
         orfas (destino removido ou renomeado),
         e criacao de Junctions para todas as skills (gap-*) em ~/.claude/skills, ~/.agents/skills e
         ~/.gemini/config/skills.
      3. Geracao do arquivo global ~/.claude/CLAUDE.md importando rules/AGENTS.md e overlays locais/corporativos
         (ex.: ~/.claude/CLAUDE.*.md) quando presentes na maquina.
      4. Sincronizacao do plugin global user-preferences do Google Antigravity (~/.gemini/config/plugins/user-preferences).
      5. Atualizacao cirurgica do servidor MCP review-hub no objeto mcpServers da RAIZ de
         ~/.gemini/config/mcp_config.json e ~/.claude.json (nunca nos mcpServers por projeto), em UTF-8 sem BOM,
         preservando integralmente todas as demais configuracoes existentes. O Python preferido e o da venv
         mcp/review-hub/.venv, quando existir.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ToolkitRoot = "",

    [Parameter(Mandatory = $false)]
    [bool]$RemoveLegacyGustavoSkills = $false
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($ToolkitRoot)) {
    $scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Definition }
    $ToolkitRoot = Split-Path -Parent $scriptDir
}
$ToolkitRoot = (Resolve-Path -LiteralPath $ToolkitRoot).Path.TrimEnd('\', '/')
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$runTimestamp = Get-Date -Format 'yyyyMMdd-HHmmss'

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
        [string]$VenvPython,

        [Parameter(Mandatory = $true)]
        [string[]]$ConfigFiles
    )

    # 1. Venv do review-hub (mcp/review-hub/.venv), onde o pacote mcp foi instalado.
    if (Test-Path -LiteralPath $VenvPython) {
        return $VenvPython
    }

    # 2. Python ja configurado anteriormente para o review-hub.
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

    # 3. Python do PATH.
    $pyCmd = Get-Command python -ErrorAction SilentlyContinue
    if ($null -ne $pyCmd -and -not [string]::IsNullOrWhiteSpace($pyCmd.Source)) {
        return $pyCmd.Source
    }

    return "python"
}

function Test-PythonHasMcpPackage {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PythonExe
    )

    # Roda fora do repositorio: a pasta mcp/ da raiz seria importada como pacote e mascararia a ausencia do mcp.
    Push-Location -LiteralPath ([System.IO.Path]::GetTempPath())
    try {
        $ErrorActionPreference = 'Continue'
        $null = & $PythonExe -c "import mcp.server.mcpserver" 2>$null
        return ($LASTEXITCODE -eq 0)
    }
    catch {
        return $false
    }
    finally {
        Pop-Location
    }
}

function Get-JsonValueEnd {
    # Devolve o indice logo apos o valor JSON que comeca em $Start (objeto, array, string ou literal).
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text,

        [Parameter(Mandatory = $true)]
        [int]$Start
    )

    $stringStops = [char[]]'"\'
    $structural = [char[]]'"{}[]'
    $first = $Text[$Start]

    if ($first -eq '"') {
        $i = $Start + 1
        while ($true) {
            $i = $Text.IndexOfAny($stringStops, $i)
            if ($i -lt 0) { throw 'JSON malformado: string sem fechamento.' }
            if ($Text[$i] -eq '\') { $i += 2; continue }
            return $i + 1
        }
    }

    if ($first -eq '{' -or $first -eq '[') {
        $depth = 0
        $i = $Start
        while ($true) {
            $i = $Text.IndexOfAny($structural, $i)
            if ($i -lt 0) { throw 'JSON malformado: objeto ou array sem fechamento.' }
            $ch = $Text[$i]
            if ($ch -eq '"') {
                $i = Get-JsonValueEnd -Text $Text -Start $i
                continue
            }
            if ($ch -eq '{' -or $ch -eq '[') { $depth++ }
            else {
                $depth--
                if ($depth -eq 0) { return $i + 1 }
            }
            $i++
        }
    }

    $i = $Start
    while ($i -lt $Text.Length -and ',}]'.IndexOf($Text[$i]) -lt 0 -and -not [char]::IsWhiteSpace($Text[$i])) {
        $i++
    }
    return $i
}

function Find-JsonObjectMember {
    # Procura um membro DIRETO do objeto que comeca em $ObjectStart ('{'), ignorando objetos aninhados.
    # Devolve [pscustomobject]@{ ValueStart; ValueEnd } ou $null.
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text,

        [Parameter(Mandatory = $true)]
        [int]$ObjectStart,

        [Parameter(Mandatory = $true)]
        [string]$Key
    )

    $structural = [char[]]'"{}[]'
    $depth = 0
    $i = $ObjectStart
    while ($true) {
        $i = $Text.IndexOfAny($structural, $i)
        if ($i -lt 0) { throw 'JSON malformado: objeto sem fechamento.' }
        $ch = $Text[$i]

        if ($ch -eq '"') {
            $end = Get-JsonValueEnd -Text $Text -Start $i
            if ($depth -eq 1) {
                $j = $end
                while ($j -lt $Text.Length -and [char]::IsWhiteSpace($Text[$j])) { $j++ }
                if ($j -lt $Text.Length -and $Text[$j] -eq ':' -and $Text.Substring($i + 1, $end - $i - 2) -ceq $Key) {
                    $v = $j + 1
                    while ($v -lt $Text.Length -and [char]::IsWhiteSpace($Text[$v])) { $v++ }
                    return [pscustomobject]@{ ValueStart = $v; ValueEnd = (Get-JsonValueEnd -Text $Text -Start $v) }
                }
            }
            $i = $end
            continue
        }

        if ($ch -eq '{' -or $ch -eq '[') { $depth++ }
        else {
            $depth--
            if ($depth -eq 0) { return $null }
        }
        $i++
    }
}

function Test-JsonContainerIsEmpty {
    # $true quando o objeto/array que comeca em $Start nao tem nenhum membro ({} ou []).
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text,

        [Parameter(Mandatory = $true)]
        [int]$Start
    )

    $j = $Start + 1
    while ($j -lt $Text.Length -and [char]::IsWhiteSpace($Text[$j])) { $j++ }
    return ($j -lt $Text.Length -and ($Text[$j] -eq '}' -or $Text[$j] -eq ']'))
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

    $fileExists = Test-Path -LiteralPath $JsonFilePath
    $raw = if ($fileExists) { [System.IO.File]::ReadAllText($JsonFilePath, [System.Text.Encoding]::UTF8) } else { '' }

    # Arquivo ausente ou vazio: cria um JSON novo so com o review-hub.
    if ([string]::IsNullOrWhiteSpace($raw)) {
        if (-not $fileExists -and -not $CreateIfMissing) {
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

    # So o mcpServers da RAIZ e considerado: o ~/.claude.json tambem tem mcpServers dentro de cada projeto,
    # e gravar num deles deixaria o review-hub disponivel apenas naquela pasta.
    $rootStart = $raw.IndexOf('{')
    if ($rootStart -lt 0) {
        Write-Warning "Conteudo inesperado em '$JsonFilePath' (sem objeto JSON na raiz); review-hub nao registrado."
        return $false
    }

    $nl = if ($raw.Contains("`r`n")) { "`r`n" } else { "`n" }
    $hubEntry = @(
        '    "review-hub": {',
        "      `"command`": `"$pyEscaped`",",
        '      "args": [',
        "        `"$scriptEscaped`"",
        '      ]',
        '    }'
    ) -join $nl

    $servers = Find-JsonObjectMember -Text $raw -ObjectStart $rootStart -Key 'mcpServers'
    if ($null -eq $servers) {
        $insertion = $nl + '  "mcpServers": {' + $nl + $hubEntry + $nl + '  }'
        if (-not (Test-JsonContainerIsEmpty -Text $raw -Start $rootStart)) { $insertion += ',' }
        $updated = $raw.Insert($rootStart + 1, $insertion)
    }
    elseif ($raw[$servers.ValueStart] -ne '{') {
        Write-Warning "'mcpServers' em '$JsonFilePath' nao e um objeto; review-hub nao registrado."
        return $false
    }
    else {
        $hub = Find-JsonObjectMember -Text $raw -ObjectStart $servers.ValueStart -Key 'review-hub'
        if ($null -eq $hub) {
            $insertion = if (Test-JsonContainerIsEmpty -Text $raw -Start $servers.ValueStart) {
                $nl + $hubEntry + $nl + '  '
            }
            else {
                $nl + $hubEntry + ','
            }
            $updated = $raw.Insert($servers.ValueStart + 1, $insertion)
        }
        else {
            # Atualiza so command e args, preservando env, disabled e demais chaves do bloco existente.
            $block = $raw.Substring($hub.ValueStart, $hub.ValueEnd - $hub.ValueStart)
            $block = [regex]::Replace($block, '("command"\s*:\s*)"[^"]*"', "`${1}`"$pyEscaped`"")
            $block = [regex]::Replace($block, '("args"\s*:\s*\[\s*)"[^"]*"(\s*\])', "`${1}`"$scriptEscaped`"`${2}")
            $updated = $raw.Substring(0, $hub.ValueStart) + $block + $raw.Substring($hub.ValueEnd)
        }
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
        $legacyItems = @(Get-ChildItem -LiteralPath $dir -Filter "gustavo-*" -Force -ErrorAction SilentlyContinue)
        foreach ($legacy in $legacyItems) {
            $isLink = ($legacy.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0
            if ($isLink) {
                Remove-DirectoryOrJunctionSafe -LiteralPath $legacy.FullName
                Write-Host "      Junction legada removida: $($legacy.FullName)" -ForegroundColor DarkYellow
            }
            else {
                # Pasta real: move para backup (fora da pasta de skills, para nao ser carregada) em vez de apagar.
                $backupDir = Join-Path (Split-Path -Parent $dir) "skills-legacy-backup\$runTimestamp"
                if (-not (Test-Path -LiteralPath $backupDir)) {
                    $null = New-Item -ItemType Directory -Path $backupDir -Force
                }
                Move-Item -LiteralPath $legacy.FullName -Destination $backupDir
                Write-Host "      Skill legada movida para backup: $($legacy.FullName) -> $backupDir" -ForegroundColor DarkYellow
            }
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

# No @import do Claude Code o caminho termina no primeiro espaco; um espaco precisa de barra invertida antes.
$agentsRuleForwardSlash = ((Join-Path $ToolkitRoot "rules\AGENTS.md") -replace '\\', '/' -replace ' ', '\ ')
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

$venvPython = Join-Path $ToolkitRoot "mcp\review-hub\.venv\Scripts\python.exe"

$pythonExe = Resolve-PythonExecutable -VenvPython $venvPython -ConfigFiles @($agMcpConfigPath, $claudeJsonPath)
if (-not (Test-PythonHasMcpPackage -PythonExe $pythonExe)) {
    Write-Host "      Aviso: o pacote 'mcp' 2.x nao foi encontrado em '$pythonExe'; o review-hub nao vai iniciar." -ForegroundColor Yellow
    Write-Host "      Crie a venv: python -m venv mcp\review-hub\.venv e depois mcp\review-hub\.venv\Scripts\python -m pip install -r mcp\review-hub\requirements.txt" -ForegroundColor Yellow
}

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
