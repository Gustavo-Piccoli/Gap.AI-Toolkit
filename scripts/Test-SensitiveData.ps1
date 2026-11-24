<#
.SYNOPSIS
    Varre o repositorio em busca de dados sensiveis, corporativos ou prefixos legados.

.DESCRIPTION
    Regras genericas (tokens de API, chaves privadas) ficam embutidas no script.
    Padroes especificos da sua organizacao NAO ficam no repositorio: sao lidos de um
    arquivo local, procurado nesta ordem:

      1. Parametro -PatternsFile
      2. Variavel de ambiente GAP_SENSITIVE_PATTERNS_FILE
      3. ~/.config/gap-toolkit/sensitive-patterns.txt  (%USERPROFILE%\.config\gap-toolkit\ no Windows)

    Formato do arquivo: uma regra por linha, "Categoria<TAB>Regex". Linhas vazias e
    linhas iniciadas por # sao ignoradas. Uma linha sem TAB vira uma regex da
    categoria "Padrao local". Veja scripts/sensitive-patterns.example.txt.

    O valor encontrado NUNCA e impresso: a saida mostra apenas arquivo, linha e
    categoria. Cada linha tambem e testada depois de "costurar" concatenacoes de
    strings ('a' + 'b', "a""b"), para pegar literais disfarcados.

.PARAMETER RepoRoot
    Raiz a varrer. Padrao: pasta pai de scripts/.

.PARAMETER IncludePaths
    Restringe a varredura a estes caminhos relativos (separador /).

.PARAMETER PatternsFile
    Caminho explicito do arquivo de padroes locais.

.PARAMETER RequirePatternsFile
    Falha (exit 2) se nenhum arquivo de padroes for encontrado.

.PARAMETER CheckGitEmail
    Tambem testa o git user.email do repositorio contra os padroes locais.

.EXAMPLE
    ./scripts/Test-SensitiveData.ps1 -CheckGitEmail

.EXAMPLE
    ./scripts/Test-SensitiveData.ps1 -PatternsFile ./scripts/sensitive-patterns.example.txt -RequirePatternsFile
#>
[CmdletBinding()]
param(
    [string]$RepoRoot,
    [string[]]$IncludePaths = @(),
    [string]$PatternsFile,
    [switch]$RequirePatternsFile,
    [switch]$CheckGitEmail
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Definition }
    $RepoRoot = Split-Path -Parent $ScriptDir
}
$ResolvedRoot = (Resolve-Path -LiteralPath $RepoRoot).Path

# ---------------------------------------------------------------------------
# Regras genericas (sem nenhum dado organizacional)
# ---------------------------------------------------------------------------
$GenericRules = @(
    @{ Name = 'Token GitHub';          Regex = '\b(ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{36}\b' },
    @{ Name = 'Token GitHub (fine-grained)'; Regex = '\bgithub_pat_[A-Za-z0-9_]{22,}\b' },
    @{ Name = 'Token Anthropic';       Regex = '\bsk-ant-[A-Za-z0-9_\-]{20,}' },
    @{ Name = 'Token OpenAI';          Regex = '\bsk-(proj-)?[A-Za-z0-9]{32,}\b' },
    @{ Name = 'Chave de acesso AWS';   Regex = '\bAKIA[0-9A-Z]{16}\b' },
    @{ Name = 'Chave privada';         Regex = '-----BEGIN ([A-Z]+ )?PRIVATE KEY-----' }
)

# Nomes antigos das skills (antes do prefixo gap-), verificados so nas pastas versionadas de conteudo.
$LegacySkillPatterns = @(
    'gustavo-commit', 'gustavo-create', 'gustavo-review', 'gustavo-fix', 'gustavo-execute',
    'gustavo-finish', 'gustavo-explain', 'gustavo-pr-description', 'gustavo-switch', 'gustavo-fluxo'
)
$LegacyScopeRegex = '^(skills|rules|adapters|mcp)/'

# ---------------------------------------------------------------------------
# Padroes locais (fora do repositorio)
# ---------------------------------------------------------------------------
function Resolve-PatternsFile {
    param([string]$Explicit)

    if (-not [string]::IsNullOrWhiteSpace($Explicit)) { return $Explicit }
    if (-not [string]::IsNullOrWhiteSpace($env:GAP_SENSITIVE_PATTERNS_FILE)) { return $env:GAP_SENSITIVE_PATTERNS_FILE }
    $default = Join-Path (Join-Path (Join-Path $HOME '.config') 'gap-toolkit') 'sensitive-patterns.txt'
    if (Test-Path -LiteralPath $default -PathType Leaf) { return $default }
    return $null
}

function Read-PatternsFile {
    param([string]$Path)

    $rules = New-Object System.Collections.Generic.List[object]
    $lineNumber = 0
    foreach ($raw in [System.IO.File]::ReadAllLines($Path)) {
        $lineNumber++
        $line = $raw.Trim()
        if ($line.Length -eq 0 -or $line.StartsWith('#')) { continue }

        $name = 'Padrao local'
        $regex = $line
        $tab = $raw.IndexOf("`t")
        if ($tab -ge 0) {
            $name = $raw.Substring(0, $tab).Trim()
            $regex = $raw.Substring($tab + 1).Trim()
        }
        try {
            $null = [regex]::new($regex)
        }
        catch {
            # Nao mostra a regex: ela pode conter o proprio dado sensivel.
            Write-Host ("[ERRO] Regex invalida na linha {0} do arquivo de padroes locais." -f $lineNumber) -ForegroundColor Red
            exit 2
        }
        $rules.Add(@{ Name = $name; Regex = $regex })
    }
    return , $rules
}

$PatternsPath = Resolve-PatternsFile -Explicit $PatternsFile
$LocalRules = @()
if ($PatternsPath) {
    if (-not (Test-Path -LiteralPath $PatternsPath -PathType Leaf)) {
        Write-Host ("[ERRO] Arquivo de padroes nao encontrado: {0}" -f $PatternsPath) -ForegroundColor Red
        exit 2
    }
    $PatternsPath = (Resolve-Path -LiteralPath $PatternsPath).Path
    $LocalRules = Read-PatternsFile -Path $PatternsPath
    Write-Host ("[INFO] {0} padrao(oes) local(is) carregado(s)." -f $LocalRules.Count)
}
elseif ($RequirePatternsFile) {
    Write-Host '[ERRO] Nenhum arquivo de padroes locais encontrado (use -PatternsFile ou GAP_SENSITIVE_PATTERNS_FILE).' -ForegroundColor Red
    exit 2
}
else {
    Write-Host '[AVISO] Sem arquivo de padroes locais: apenas as regras genericas serao aplicadas.' -ForegroundColor Yellow
    Write-Host '        Crie ~/.config/gap-toolkit/sensitive-patterns.txt a partir de scripts/sensitive-patterns.example.txt.' -ForegroundColor Yellow
}

$AllRules = New-Object System.Collections.Generic.List[object]
foreach ($r in $GenericRules) { $AllRules.Add($r) }
foreach ($r in $LocalRules) { $AllRules.Add($r) }

# ---------------------------------------------------------------------------
# Selecao de arquivos
# ---------------------------------------------------------------------------
function Get-CandidateFiles {
    param([string]$Root)

    $files = $null
    $git = Get-Command git -ErrorAction SilentlyContinue
    if ($git -and (Test-Path -LiteralPath (Join-Path $Root '.git'))) {
        # Versionados + nao rastreados que nao estao no .gitignore.
        $files = & git -C $Root ls-files --cached --others --exclude-standard 2>$null
        if ($LASTEXITCODE -ne 0) { $files = $null }
    }
    if ($null -eq $files) {
        $files = Get-ChildItem -LiteralPath $Root -Recurse -File -Force |
            Where-Object { $_.FullName -notmatch '[\\/]\.git([\\/]|$)' } |
            ForEach-Object { $_.FullName.Substring($Root.Length).TrimStart('\', '/') -replace '\\', '/' }
    }
    return @($files | Sort-Object -Unique)
}

# Remove separadores de concatenacao: 'a' + 'b'  ->  'ab' ;  "a""b" -> "ab" ;  "a" + "b" -> "ab"
$ConcatJoinRegex = [regex]"(['""])\s*\+?\s*\1"

$Violations = New-Object System.Collections.Generic.List[object]
$ScannedCount = 0

foreach ($RelativePath in (Get-CandidateFiles -Root $ResolvedRoot)) {
    if ($IncludePaths.Count -gt 0 -and ($IncludePaths -notcontains $RelativePath)) { continue }

    $FullPath = Join-Path $ResolvedRoot $RelativePath
    if (-not (Test-Path -LiteralPath $FullPath -PathType Leaf)) { continue }
    if ($PatternsPath -and ((Resolve-Path -LiteralPath $FullPath).Path -eq $PatternsPath)) { continue }

    try {
        $Lines = [System.IO.File]::ReadAllLines($FullPath)
    }
    catch {
        Write-Host ("[AVISO] Nao foi possivel ler {0}" -f $RelativePath) -ForegroundColor Yellow
        continue
    }
    $ScannedCount++

    $IsLegacyScope = $RelativePath -match $LegacyScopeRegex

    for ($i = 0; $i -lt $Lines.Count; $i++) {
        $Line = $Lines[$i]
        $Joined = $ConcatJoinRegex.Replace($Line, '')

        foreach ($Rule in $AllRules) {
            if (($Line -imatch $Rule.Regex) -or ($Joined -imatch $Rule.Regex)) {
                $Violations.Add([PSCustomObject]@{ File = $RelativePath; Line = $i + 1; Category = $Rule.Name })
            }
        }

        if ($IsLegacyScope) {
            foreach ($Legacy in $LegacySkillPatterns) {
                if ($Line -imatch [regex]::Escape($Legacy)) {
                    $Violations.Add([PSCustomObject]@{ File = $RelativePath; Line = $i + 1; Category = 'Prefixo legado de skill' })
                }
            }
        }
    }
}

# ---------------------------------------------------------------------------
# E-mail do autor (opcional)
# ---------------------------------------------------------------------------
$EmailViolation = $null
if ($CheckGitEmail) {
    $email = (& git -C $ResolvedRoot config user.email 2>$null)
    # Enderecos noreply do GitHub nao expoem dados pessoais nem corporativos.
    if (-not [string]::IsNullOrWhiteSpace($email) -and ($email -notmatch '@users\.noreply\.github\.com$')) {
        foreach ($Rule in $LocalRules) {
            if ($email -imatch $Rule.Regex) { $EmailViolation = $Rule.Name; break }
        }
    }
}

# ---------------------------------------------------------------------------
# Resultado (sem nunca exibir o valor encontrado)
# ---------------------------------------------------------------------------
$failed = $false
if ($EmailViolation) {
    Write-Host ("[ERRO] O git user.email deste repositorio corresponde a categoria '{0}'." -f $EmailViolation) -ForegroundColor Red
    Write-Host '       Configure um e-mail pessoal ou noreply: git config user.email "<id>+<usuario>@users.noreply.github.com"' -ForegroundColor Red
    $failed = $true
}

if ($Violations.Count -gt 0) {
    Write-Host ('[ERRO] {0} ocorrencia(s) de dados sensiveis, corporativos ou prefixos legados:' -f $Violations.Count) -ForegroundColor Red
    foreach ($V in $Violations) {
        Write-Host ('  - {0}:{1} [{2}]' -f $V.File, $V.Line, $V.Category) -ForegroundColor Yellow
    }
    $failed = $true
}

if ($failed) { exit 1 }

Write-Host ('[OK] Varredura concluida em {0} arquivo(s) com {1} regra(s). Nenhum dado sensivel encontrado.' -f $ScannedCount, $AllRules.Count) -ForegroundColor Green
exit 0
