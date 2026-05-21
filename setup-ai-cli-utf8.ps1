# setup-ai-cli-utf8.ps1
# Windows AI CLI 乱码修复一键脚本
# 支持 Codex / Claude Code / OpenCode / Kimi Code / Qwen Code / Kilo Code / Cursor Agent 等 CLI
# 用法:
#   powershell -ExecutionPolicy Bypass -File .\setup-ai-cli-utf8.ps1
#   pwsh -ExecutionPolicy Bypass -File .\setup-ai-cli-utf8.ps1
# 本文件须保存为 UTF-8 with BOM（否则 PS 5.1 在中文 Windows 上可能无法解析中文）

param(
    [switch]$Codex,        # 只配置 Codex CLI
    [switch]$Claude,       # 只配置 Claude Code
    [switch]$OpenCode,     # 只配置 OpenCode
    [switch]$Kimi,         # 只配置 Kimi Code（命令: kimi）
    [switch]$Qwen,         # 只配置 Qwen Code（命令: qwen）
    [switch]$Kilo,         # 只配置 Kilo Code（命令: kilo）
    [switch]$CursorAgent,  # 只配置 Cursor Agent CLI（命令: agent）
    [switch]$All           # 配置所有已检测到的已安装工具（默认）
)

# 同类 AI CLI 注册表（Command=PATH 中的可执行名；Alt=备用命令名）
$Script:AiCliTools = @(
    @{ Switch = 'Codex';        Command = 'codex';  Label = 'Codex CLI';      Dir = '.codex';     Rules = 'AGENTS.md';  Alt = @() }
    @{ Switch = 'Claude';       Command = 'claude'; Label = 'Claude Code';    Dir = '.claude';    Rules = 'CLAUDE.md'; Alt = @() }
    @{ Switch = 'OpenCode';     Command = 'opencode'; Label = 'OpenCode';     Dir = '.opencode';  Rules = 'AGENTS.md';  Alt = @() }
    @{ Switch = 'Kimi';         Command = 'kimi';   Label = 'Kimi Code';      Dir = '.kimi';      Rules = 'AGENTS.md';  Alt = @('kimi-cli') }
    @{ Switch = 'Qwen';         Command = 'qwen';   Label = 'Qwen Code';      Dir = '.qwen';      Rules = 'AGENTS.md';  Alt = @('qwen-code') }
    @{ Switch = 'Kilo';         Command = 'kilo';   Label = 'Kilo Code';      Dir = '.kilocode';  Rules = 'AGENTS.md';  Alt = @('kilocode') }
    @{ Switch = 'CursorAgent';  Command = 'agent';  Label = 'Cursor Agent';   Dir = '.cursor';    Rules = 'AGENTS.md';  Alt = @('cursor-agent') }
)

$ErrorActionPreference = "Stop"

function Set-Utf8File {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Value,
        [switch]$WithBom
    )
    $parent = Split-Path $Path -Parent
    if ($parent -and -not (Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    $enc = if ($WithBom) {
        New-Object System.Text.UTF8Encoding $true
    } else {
        New-Object System.Text.UTF8Encoding $false
    }
    [System.IO.File]::WriteAllText($Path, $Value, $enc)
}

function Test-UserPathContains {
    param([Parameter(Mandatory)][string]$Dir)
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if (-not $userPath) { return $false }
    $normalized = $Dir.TrimEnd('\')
    foreach ($segment in ($userPath -split ';')) {
        if ($segment.TrimEnd('\') -eq $normalized) { return $true }
    }
    return $false
}

function Update-ProfileBootstrap {
    param(
        [Parameter(Mandatory)][string]$ProfilePath,
        [Parameter(Mandatory)][string]$Label
    )
    $Marker = "# >>> AI CLI UTF-8 bootstrap >>>"
    $Snippet = @"

# >>> AI CLI UTF-8 bootstrap >>>
`$AiCliUtf8Core = Join-Path `$env:USERPROFILE 'bin\ai-cli-utf8-core.ps1'
if (Test-Path `$AiCliUtf8Core) {
  . `$AiCliUtf8Core
}
# <<< AI CLI UTF-8 bootstrap <<<
"@

    $profileDir = Split-Path $ProfilePath -Parent
    if ($profileDir) {
        New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
    }

    $needsPatch = $true
    if (Test-Path $ProfilePath) {
        $needsPatch = -not (Select-String -Path $ProfilePath -SimpleMatch $Marker -Quiet)
    }

    if ($needsPatch) {
        $existing = if (Test-Path $ProfilePath) { Get-Content -Path $ProfilePath -Raw -Encoding UTF8 } else { "" }
        if ($null -eq $existing) { $existing = "" }
        Set-Utf8File -Path $ProfilePath -Value ($existing + $Snippet) -WithBom
        Write-Host "  $Label Profile 已添加 UTF-8 引导" -ForegroundColor Green
    } else {
        Write-Host "  $Label Profile 已存在 UTF-8 引导" -ForegroundColor DarkYellow
    }
}

function Enable-CodexPowerShellUtf8Config {
    param([Parameter(Mandatory)][string]$ConfigPath)

    if (-not (Test-Path $ConfigPath)) {
        Set-Utf8File -Path $ConfigPath -Value "[features]`npowershell_utf8 = true`n"
        return $true
    }

    $content = Get-Content -Path $ConfigPath -Raw -Encoding UTF8
    if ($content -match 'powershell_utf8\s*=\s*true') {
        return $false
    }

    if ($content -match '\[features\]') {
        $content = $content.TrimEnd() + "`npowershell_utf8 = true`n"
    } else {
        $content = $content.TrimEnd() + "`n`n[features]`npowershell_utf8 = true`n"
    }
    Set-Utf8File -Path $ConfigPath -Value $content
    return $true
}

function Update-ClaudeSettingsJson {
    param([Parameter(Mandatory)][string]$SettingsPath)

    $bashCandidates = @(
        (Join-Path $env:ProgramFiles 'Git\bin\bash.exe')
    )
    if (${env:ProgramFiles(x86)}) {
        $bashCandidates += (Join-Path ${env:ProgramFiles(x86)} 'Git\bin\bash.exe')
    }
    $gitBash = $bashCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1

    $settings = [ordered]@{
        env          = [ordered]@{
            CLAUDE_CODE_USE_POWERSHELL_TOOL = '1'
        }
        defaultShell = 'powershell'
    }
    if ($gitBash) {
        $settings.env['CLAUDE_CODE_GIT_BASH_PATH'] = $gitBash
    }

    if (Test-Path $SettingsPath) {
        try {
            $existing = Get-Content -Path $SettingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($existing.env) {
                foreach ($key in $settings.env.Keys) {
                    if (-not ($existing.env.PSObject.Properties.Name -contains $key)) {
                        $existing.env | Add-Member -NotePropertyName $key -NotePropertyValue $settings.env[$key] -Force
                    }
                }
            } else {
                $existing | Add-Member -NotePropertyName env -NotePropertyValue ([pscustomobject]$settings.env) -Force
            }
            if (-not ($existing.PSObject.Properties.Name -contains 'defaultShell')) {
                $existing | Add-Member -NotePropertyName defaultShell -NotePropertyValue $settings.defaultShell -Force
            }
            $settings = $existing
        } catch {
            Write-Host "  无法解析现有 settings.json，将写入默认 UTF-8 配置" -ForegroundColor DarkYellow
        }
    }

    $json = $settings | ConvertTo-Json -Depth 6
    Set-Utf8File -Path $SettingsPath -Value $json
}

function Get-WindowsTerminalSettingsPath {
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\settings.json')
    )
    $wtPackages = Get-ChildItem (Join-Path $env:LOCALAPPDATA 'Packages') -Filter 'Microsoft.WindowsTerminal_*' -Directory -ErrorAction SilentlyContinue
    foreach ($pkg in $wtPackages) {
        $candidates += (Join-Path $pkg.FullName 'LocalState\settings.json')
    }
    return $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
}

function Set-WindowsTerminalCjkFont {
    param([Parameter(Mandatory)][string]$SettingsPath)

    try {
        $wt = Get-Content -Path $SettingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
    } catch {
        Write-Host "  无法解析 Windows Terminal settings.json，请手动设置字体" -ForegroundColor DarkYellow
        return $false
    }

    $fontFace = 'Cascadia Mono'
    $changed = $false

    if (-not $wt.profiles) {
        $wt | Add-Member -NotePropertyName profiles -NotePropertyValue ([pscustomobject]@{}) -Force
        $changed = $true
    }
    if (-not $wt.profiles.defaults) {
        $wt.profiles | Add-Member -NotePropertyName defaults -NotePropertyValue ([pscustomobject]@{}) -Force
        $changed = $true
    }

    if ($wt.profiles.defaults.PSObject.Properties.Name -contains 'font') {
        if (-not $wt.profiles.defaults.font.face) {
            $wt.profiles.defaults.font.face = $fontFace
            $changed = $true
        }
    } elseif ($wt.profiles.defaults.PSObject.Properties.Name -contains 'fontFace') {
        if (-not $wt.profiles.defaults.fontFace) {
            $wt.profiles.defaults.fontFace = $fontFace
            $changed = $true
        }
    } else {
        $wt.profiles.defaults | Add-Member -NotePropertyName font -NotePropertyValue ([pscustomobject]@{ face = $fontFace }) -Force
        $changed = $true
    }

    if ($changed) {
        $json = $wt | ConvertTo-Json -Depth 32
        Set-Utf8File -Path $SettingsPath -Value $json
    }
    return $changed
}

function Set-VscodeTerminalFont {
    param([Parameter(Mandatory)][string]$SettingsPath)

    $fontFamily = "'Cascadia Code PL', 'Sarasa Mono SC', 'Cascadia Mono', 'Consolas'"
    $changed = $false

    if (Test-Path $SettingsPath) {
        try {
            $vs = Get-Content -Path $SettingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
            if (-not ($vs.PSObject.Properties.Name -contains 'terminal.integrated.fontFamily')) {
                $vs | Add-Member -NotePropertyName 'terminal.integrated.fontFamily' -NotePropertyValue $fontFamily -Force
                $changed = $true
            }
            if ($changed) {
                $json = $vs | ConvertTo-Json -Depth 6
                Set-Utf8File -Path $SettingsPath -Value $json
            }
        } catch {
            Write-Host "  无法解析 VS Code settings.json，请手动设置终端字体" -ForegroundColor DarkYellow
            return $false
        }
    } else {
        $vs = [ordered]@{
            'terminal.integrated.fontFamily' = $fontFamily
        }
        $json = [pscustomobject]$vs | ConvertTo-Json -Depth 4
        Set-Utf8File -Path $SettingsPath -Value $json
        $changed = $true
    }
    return $changed
}

function Add-AgentEncodingRules {
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [Parameter(Mandatory)][string]$Label,
        [Parameter(Mandatory)][string]$Rules
    )
    $existing = if (Test-Path $FilePath) { Get-Content $FilePath -Raw -Encoding UTF8 } else { "" }
    if ($null -eq $existing) { $existing = "" }
    if ($existing -notmatch 'Windows encoding rules') {
        Set-Utf8File -Path $FilePath -Value ($existing + $Rules)
        Write-Host "  $Label 已添加编码规则" -ForegroundColor Green
    } else {
        Write-Host "  $Label 已包含编码规则" -ForegroundColor DarkYellow
    }
}

function Get-AiCliSelectionFlags {
    [ordered]@{
        All          = [bool]$All
        Codex        = [bool]$Codex
        Claude       = [bool]$Claude
        OpenCode     = [bool]$OpenCode
        Kimi         = [bool]$Kimi
        Qwen         = [bool]$Qwen
        Kilo         = [bool]$Kilo
        CursorAgent  = [bool]$CursorAgent
    }
}

function Test-AiCliToolSelected {
    param(
        [Parameter(Mandatory)][string]$SwitchName,
        [Parameter(Mandatory)][hashtable]$Flags
    )
    return $Flags.All -or $Flags[$SwitchName]
}

function Resolve-ShimTargetPath {
    param(
        [Parameter(Mandatory)][string]$ShimPath,
        [Parameter(Mandatory)][string]$RawTarget
    )
    $target = $RawTarget -replace '%~dp0\\?', ''
    if ([System.IO.Path]::IsPathRooted($target)) {
        return $target
    }
    $base = Split-Path $ShimPath -Parent
    try {
        return [System.IO.Path]::GetFullPath((Join-Path $base $target))
    } catch {
        return $null
    }
}

function Test-CliCommandTargetExists {
    param([Parameter(Mandatory)]$CommandInfo)

    $source = $CommandInfo.Source
    if (-not (Test-Path -LiteralPath $source)) {
        return $false
    }

    if ($source -match '\.exe$') {
        return Test-Path -LiteralPath $source
    }

    $text = Get-Content -LiteralPath $source -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
    if (-not $text) {
        return $true
    }

    if ($text -match 'cmd-shim-target=(.+)') {
        return Test-Path -LiteralPath ($Matches[1].Trim())
    }

    $exeTarget = $null
    if ($text -match '&\s*"([^"]+\.exe)"') {
        $exeTarget = $Matches[1]
    } elseif ($text -match '@"([^"]+\.exe)"') {
        $exeTarget = $Matches[1]
    } elseif ($text -match '"(\.\./[^"]+\.exe)"') {
        $exeTarget = $Matches[1]
    }

    if ($exeTarget) {
        $full = Resolve-ShimTargetPath -ShimPath $source -RawTarget $exeTarget
        if ($full) {
            return Test-Path -LiteralPath $full
        }
        return $false
    }

    if ($CommandInfo.CommandType -eq 'Application') {
        return $true
    }

    return $true
}

function Get-RunnableCliCommand {
    param([Parameter(Mandatory)][string[]]$Names)

    foreach ($name in $Names) {
        foreach ($cmd in (Get-Command $name -All -ErrorAction SilentlyContinue)) {
            if (Test-CliCommandTargetExists -CommandInfo $cmd) {
                return $cmd
            }
        }
    }
    return $null
}

function Resolve-AiCliTool {
    param([Parameter(Mandatory)][hashtable]$Tool)
    $names = @($Tool.Command) + @($Tool.Alt)
    $searchNames = @()
    foreach ($name in $names) {
        $searchNames += $name
        if ($name -notmatch '\.') {
            $searchNames += "$name.cmd"
            $searchNames += "$name.ps1"
        }
    }
    $searchNames = $searchNames | Select-Object -Unique

    $cmd = Get-RunnableCliCommand -Names $searchNames
    if ($cmd) {
        return [pscustomobject]@{
            Installed  = $true
            Command    = $Tool.Command
            InvokeName = $cmd.Name
            Source     = $cmd.Source
            Label      = $Tool.Label
        }
    }
    return [pscustomobject]@{
        Installed  = $false
        Command    = $Tool.Command
        InvokeName = $null
        Source     = $null
        Label      = $Tool.Label
    }
}

function Get-WrapperCommandName {
    param([Parameter(Mandatory)][string]$CommandName)
    # 命令名含连字符时 wrapper 文件仍用原名（如 cursor-agentu）
    return "${CommandName}u"
}

# 如果没有指定任何工具开关，默认处理所有已安装的工具
$AnyToolSwitch = $Codex -or $Claude -or $OpenCode -or $Kimi -or $Qwen -or $Kilo -or $CursorAgent
if (-not $AnyToolSwitch) {
    $All = $true
}

$SelectionFlags = Get-AiCliSelectionFlags
$DetectedTools = @{}
foreach ($tool in $Script:AiCliTools) {
    $DetectedTools[$tool.Switch] = Resolve-AiCliTool -Tool $tool
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Windows AI CLI UTF-8 修复脚本" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# === 诊断当前状态 ===
Write-Host "`n=== 诊断当前编码状态 ===" -ForegroundColor Yellow

$CurrentCodePage = cmd /c chcp 2>&1
Write-Host "当前 Code Page: $CurrentCodePage"

$ConsoleOutEnc = [Console]::OutputEncoding.WebName
$OutputEnc = $OutputEncoding.WebName
Write-Host "Console OutputEncoding: $ConsoleOutEnc"
Write-Host "OutputEncoding: $OutputEnc"

if ($ConsoleOutEnc -eq "utf-8" -and $OutputEnc -eq "utf-8") {
    Write-Host "当前会话编码已是 UTF-8。" -ForegroundColor Green
    Write-Host "仍将写入持久化配置（Profile / wrapper / 工具规则等）。" -ForegroundColor DarkYellow
} else {
    Write-Host "当前会话编码不是 UTF-8，需要修复。" -ForegroundColor Red
}

# === [1/9] 安装 PowerShell 7 ===
Write-Host "`n=== [1/9] 检查并安装 PowerShell 7 ===" -ForegroundColor Yellow

$HasPwsh = Get-Command pwsh -ErrorAction SilentlyContinue
if ($HasPwsh) {
    Write-Host "PowerShell 7 已安装: $(pwsh -Version)" -ForegroundColor Green
} else {
    Write-Host "正在通过 winget 安装 PowerShell 7..." -ForegroundColor Yellow
    winget install --id Microsoft.PowerShell --source winget --accept-source-agreements --accept-package-agreements
    if ($LASTEXITCODE -eq 0) {
        Write-Host "PowerShell 7 安装完成（请新开终端使 pwsh 生效）" -ForegroundColor Green
    } else {
        Write-Host "winget 安装失败，请手动安装: https://github.com/PowerShell/PowerShell" -ForegroundColor Red
    }
}

# === [2/9] 创建 UTF-8 Core 脚本 ===
Write-Host "`n=== [2/9] 创建 UTF-8 引导脚本 ===" -ForegroundColor Yellow

$BinDir = Join-Path $env:USERPROFILE "bin"
New-Item -ItemType Directory -Path $BinDir -Force | Out-Null

$CoreScript = Join-Path $BinDir "ai-cli-utf8-core.ps1"

$CoreContent = @'
# ai-cli-utf8-core.ps1
# 所有 AI CLI wrapper 共用的 UTF-8 引导脚本

try {
    chcp 65001 | Out-Null
} catch {
    # chcp 不可用时忽略
}

$Utf8NoBom = [System.Text.UTF8Encoding]::new($false)

try { [Console]::InputEncoding  = $Utf8NoBom } catch {}
try { [Console]::OutputEncoding = $Utf8NoBom } catch {}

$global:OutputEncoding = $Utf8NoBom

# PowerShell 7+ 默认写文件编码
if ($PSVersionTable.PSEdition -eq 'Core') {
    $PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'
    $PSDefaultParameterValues['Set-Content:Encoding'] = 'utf8'
    $PSDefaultParameterValues['Add-Content:Encoding'] = 'utf8'
}

# 语言运行时编码
$env:PYTHONUTF8       = "1"
$env:PYTHONIOENCODING = "utf-8"
$env:LESSCHARSET      = "utf-8"

# Git Bash / MSYS 兼容
if (-not $env:LANG) {
    $env:LANG = "C.UTF-8"
}
'@

Set-Utf8File -Path $CoreScript -Value $CoreContent -WithBom
Write-Host "核心引导脚本已创建: $CoreScript" -ForegroundColor Green

$InvokeScript = Join-Path $BinDir 'ai-cli-invoke.ps1'
$InvokeContent = @'
# ai-cli-invoke.ps1 - 选择 PATH 中第一个目标可执行的 CLI（跳过损坏的 pnpm shim）

function Resolve-ShimTargetPath {
    param(
        [Parameter(Mandatory)][string]$ShimPath,
        [Parameter(Mandatory)][string]$RawTarget
    )
    $target = $RawTarget -replace '%~dp0\\?', ''
    if ([System.IO.Path]::IsPathRooted($target)) {
        return $target
    }
    $base = Split-Path $ShimPath -Parent
    try {
        return [System.IO.Path]::GetFullPath((Join-Path $base $target))
    } catch {
        return $null
    }
}

function Test-CliCommandTargetExists {
    param([Parameter(Mandatory)]$CommandInfo)

    $source = $CommandInfo.Source
    if (-not (Test-Path -LiteralPath $source)) {
        return $false
    }

    if ($source -match '\.exe$') {
        return Test-Path -LiteralPath $source
    }

    $text = Get-Content -LiteralPath $source -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
    if (-not $text) {
        return $true
    }

    if ($text -match 'cmd-shim-target=(.+)') {
        return Test-Path -LiteralPath ($Matches[1].Trim())
    }

    $exeTarget = $null
    if ($text -match '&\s*"([^"]+\.exe)"') {
        $exeTarget = $Matches[1]
    } elseif ($text -match '@"([^"]+\.exe)"') {
        $exeTarget = $Matches[1]
    } elseif ($text -match '"(\.\./[^"]+\.exe)"') {
        $exeTarget = $Matches[1]
    }

    if ($exeTarget) {
        $full = Resolve-ShimTargetPath -ShimPath $source -RawTarget $exeTarget
        if ($full) {
            return Test-Path -LiteralPath $full
        }
        return $false
    }

    if ($CommandInfo.CommandType -eq 'Application') {
        return $true
    }

    return $true
}

function Get-RunnableCliCommand {
    param([Parameter(Mandatory)][string[]]$Names)

    foreach ($name in $Names) {
        foreach ($cmd in (Get-Command $name -All -ErrorAction SilentlyContinue)) {
            if (Test-CliCommandTargetExists -CommandInfo $cmd) {
                return $cmd
            }
        }
    }
    return $null
}

function Invoke-AiCliWithUtf8 {
    param(
        [Parameter(Mandatory)][string[]]$CommandNames,
        [string[]]$Arguments = @()
    )

    $cmd = Get-RunnableCliCommand -Names $CommandNames
    if (-not $cmd) {
        $list = $CommandNames -join ', '
        Write-Error "No working command found for: $list. Broken package shim? Try: pnpm add -g <package> or npm install -g <package>"
        exit 127
    }

    if ($cmd.CommandType -eq 'Application') {
        & $cmd.Source @Arguments
    } else {
        & $cmd.Source @Arguments
    }
    exit $LASTEXITCODE
}
'@

Set-Utf8File -Path $InvokeScript -Value $InvokeContent
Write-Host "CLI 调用辅助脚本已创建: $InvokeScript" -ForegroundColor Green

# === [3/9] 创建 Wrapper 脚本 ===
Write-Host "`n=== [3/9] 创建 UTF-8 Wrapper ===" -ForegroundColor Yellow

function New-Wrapper {
    param(
        [Parameter(Mandatory)][string]$WrapperBase,
        [Parameter(Mandatory)][string[]]$CommandNames
    )

    $Ps1Path = Join-Path $BinDir "$(Get-WrapperCommandName -CommandName $WrapperBase).ps1"
    $CmdPath = Join-Path $BinDir "$(Get-WrapperCommandName -CommandName $WrapperBase).cmd"
    $namesLiteral = ($CommandNames | ForEach-Object { "'$_'" }) -join ', '

    $Ps1Content = @"
param(
  [Parameter(ValueFromRemainingArguments = `$true)]
  [string[]]`$RemainingArgs
)

. "`$PSScriptRoot\ai-cli-utf8-core.ps1"
. "`$PSScriptRoot\ai-cli-invoke.ps1"

Invoke-AiCliWithUtf8 -CommandNames @($namesLiteral) -Arguments `$RemainingArgs
"@

    Set-Utf8File -Path $Ps1Path -Value $Ps1Content

    $wrapName = Get-WrapperCommandName -CommandName $WrapperBase
    $CmdContent = @"
@echo off
chcp 65001 >nul
where pwsh >nul 2>nul
if errorlevel 1 (
  powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0$($wrapName).ps1" %*
) else (
  pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0$($wrapName).ps1" %*
)
"@

    Set-Content -Path $CmdPath -Value $CmdContent -Encoding ASCII

    Write-Host "  $wrapName.ps1 / $wrapName.cmd 已创建" -ForegroundColor Green
}

function Get-ToolCommandNames {
    param([Parameter(Mandatory)][hashtable]$Tool)
    $names = @($Tool.Command) + @($Tool.Alt)
    $expanded = @()
    foreach ($name in $names) {
        $expanded += $name
        if ($name -notmatch '\.') {
            $expanded += "$name.cmd"
            $expanded += "$name.ps1"
        }
    }
    return ($expanded | Select-Object -Unique)
}

foreach ($tool in $Script:AiCliTools) {
    if (-not (Test-AiCliToolSelected -SwitchName $tool.Switch -Flags $SelectionFlags)) {
        continue
    }
    $det = $DetectedTools[$tool.Switch]
    if ($det.Installed) {
        $cmdNames = Get-ToolCommandNames -Tool $tool
        New-Wrapper -WrapperBase $tool.Command -CommandNames $cmdNames
        if ($det.InvokeName -and $det.InvokeName -ne $tool.Command) {
            Write-Host "    （将优先调用: $($det.InvokeName) @ $($det.Source)）" -ForegroundColor DarkGray
        }
    } else {
        $altHint = if ($tool.Alt.Count -gt 0) { "（亦尝试: $($tool.Alt -join ', ')）" } else { "" }
        Write-Host "  $($tool.Label) 未安装，跳过 wrapper $altHint" -ForegroundColor DarkYellow
    }
}

# === [4/9] 配置 PATH ===
Write-Host "`n=== [4/9] 配置用户 PATH ===" -ForegroundColor Yellow

if (-not (Test-UserPathContains -Dir $BinDir)) {
    $UserPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $NewPath = if ($UserPath) { "$UserPath;$BinDir" } else { $BinDir }
    [Environment]::SetEnvironmentVariable("Path", $NewPath, "User")
    $env:Path = "$env:Path;$BinDir"
    Write-Host "已将 $BinDir 添加到用户 PATH" -ForegroundColor Green
} else {
    Write-Host "$BinDir 已在 PATH 中" -ForegroundColor DarkYellow
}

# === [5/9] 配置 PowerShell Profile（5.1 + 7 固定路径）===
Write-Host "`n=== [5/9] 配置 PowerShell Profile ===" -ForegroundColor Yellow

$Docs = [Environment]::GetFolderPath('MyDocuments')
$Ps51Profile = Join-Path $Docs 'WindowsPowerShell\Microsoft.PowerShell_profile.ps1'
$PwshProfile = Join-Path $Docs 'PowerShell\Microsoft.PowerShell_profile.ps1'

Update-ProfileBootstrap -ProfilePath $Ps51Profile -Label 'PowerShell 5.1'
Update-ProfileBootstrap -ProfilePath $PwshProfile -Label 'PowerShell 7'

# === [6/9] Git UTF-8 + AGENTS/CLAUDE 规则 ===
Write-Host "`n=== [6/9] 配置 Git UTF-8 和工具编码规则 ===" -ForegroundColor Yellow

if (Get-Command git -ErrorAction SilentlyContinue) {
    $gitOk = $true
    git config --global core.quotepath false
    if ($LASTEXITCODE -ne 0) { $gitOk = $false }
    git config --global i18n.logOutputEncoding utf-8
    if ($LASTEXITCODE -ne 0) { $gitOk = $false }
    git config --global i18n.commitEncoding utf-8
    if ($LASTEXITCODE -ne 0) { $gitOk = $false }
    if ($gitOk) {
        Write-Host "Git UTF-8 配置完成" -ForegroundColor Green
    } else {
        Write-Host "Git 部分配置失败，请检查 git config --global" -ForegroundColor DarkYellow
    }
} else {
    Write-Host "Git 未安装，跳过" -ForegroundColor DarkYellow
}

$EncodingRules = @"

# Windows encoding rules

- When running PowerShell on Windows, set UTF-8 first:
  `chcp 65001; [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new(`$false); `$OutputEncoding = [System.Text.UTF8Encoding]::new(`$false)`.
- Do not judge source file corruption from terminal-rendered mojibake alone.
- Before rewriting files that contain non-ASCII text, validate bytes using strict UTF-8 decoding.
- Preserve existing file encoding where possible.
- Prefer UTF-8 without BOM for cross-platform source files.
- For `.ps1` scripts intended for Windows PowerShell 5.1 with non-ASCII characters, UTF-8 with BOM may be safer.
"@

foreach ($tool in $Script:AiCliTools) {
    if (-not (Test-AiCliToolSelected -SwitchName $tool.Switch -Flags $SelectionFlags)) {
        continue
    }
    $det = $DetectedTools[$tool.Switch]
    if (-not $det.Installed) {
        continue
    }
    $configDir = Join-Path $env:USERPROFILE $tool.Dir
    if (-not (Test-Path $configDir)) {
        New-Item -ItemType Directory -Path $configDir -Force | Out-Null
    }
    $rulesPath = Join-Path $configDir $tool.Rules
    Add-AgentEncodingRules -FilePath $rulesPath -Label "$($tool.Label) $($tool.Rules)" -Rules $EncodingRules
}

# === [7/9] Codex powershell_utf8 ===
Write-Host "`n=== [7/9] 配置 Codex powershell_utf8 ===" -ForegroundColor Yellow

if ((Test-AiCliToolSelected -SwitchName 'Codex' -Flags $SelectionFlags) -and $DetectedTools['Codex'].Installed) {
    $codexFeatureOk = $false
    try {
        $featureList = & codex features list 2>&1 | Out-String
        if ($featureList -match 'powershell_utf8') {
            & codex features enable powershell_utf8 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  已通过 codex features 启用 powershell_utf8" -ForegroundColor Green
                $codexFeatureOk = $true
            } else {
                Write-Host "  codex features enable 失败，将尝试写入 config.toml" -ForegroundColor DarkYellow
            }
        } else {
            Write-Host "  当前 Codex 版本无 powershell_utf8 feature，将写入 config.toml" -ForegroundColor DarkYellow
        }
    } catch {
        Write-Host "  无法执行 codex features，将写入 config.toml" -ForegroundColor DarkYellow
    }

    if (-not $codexFeatureOk) {
        $codexConfig = Join-Path $env:USERPROFILE '.codex\config.toml'
        if (Enable-CodexPowerShellUtf8Config -ConfigPath $codexConfig) {
            Write-Host "  已在 $codexConfig 设置 powershell_utf8 = true" -ForegroundColor Green
        } else {
            Write-Host "  config.toml 已包含 powershell_utf8" -ForegroundColor DarkYellow
        }
    }
} else {
    Write-Host "  Codex 未安装或未选中 -Codex，跳过" -ForegroundColor DarkYellow
}

# === [8/9] Claude shell 配置 ===
Write-Host "`n=== [8/9] 配置 Claude Code shell ===" -ForegroundColor Yellow

if ((Test-AiCliToolSelected -SwitchName 'Claude' -Flags $SelectionFlags) -and $DetectedTools['Claude'].Installed) {
    $claudeDir = Join-Path $env:USERPROFILE '.claude'
    if (-not (Test-Path $claudeDir)) {
        New-Item -ItemType Directory -Path $claudeDir -Force | Out-Null
    }
    $claudeSettings = Join-Path $claudeDir 'settings.json'
    Update-ClaudeSettingsJson -SettingsPath $claudeSettings
    Write-Host "  已更新 $claudeSettings" -ForegroundColor Green
    Write-Host "    - CLAUDE_CODE_USE_POWERSHELL_TOOL=1, defaultShell=powershell" -ForegroundColor DarkGray
    Write-Host "    - 若 PowerShell 仍乱码可改为 USE_POWERSHELL_TOOL=0 改用 Git Bash" -ForegroundColor DarkGray
} else {
    Write-Host "  Claude 未安装或未选中 -Claude，跳过" -ForegroundColor DarkYellow
}

# === [9/9] 终端字体 ===
Write-Host "`n=== [9/9] 配置终端 CJK 字体 ===" -ForegroundColor Yellow

$wtSettings = Get-WindowsTerminalSettingsPath
if ($wtSettings) {
    if (Set-WindowsTerminalCjkFont -SettingsPath $wtSettings) {
        Write-Host "  Windows Terminal 已设置默认字体: Cascadia Mono ($wtSettings)" -ForegroundColor Green
    } else {
        Write-Host "  Windows Terminal 已有字体配置，未修改" -ForegroundColor DarkYellow
    }
} else {
    Write-Host "  未找到 Windows Terminal settings.json，请手动设置字体" -ForegroundColor DarkYellow
}

$editorFontTargets = @(
    @{ Path = (Join-Path $env:APPDATA 'Code\User\settings.json'); Label = 'VS Code' }
    @{ Path = (Join-Path $env:APPDATA 'Cursor\User\settings.json'); Label = 'Cursor' }
)
foreach ($editor in $editorFontTargets) {
    if (Set-VscodeTerminalFont -SettingsPath $editor.Path) {
        Write-Host "  $($editor.Label) 已设置 terminal.integrated.fontFamily" -ForegroundColor Green
    } else {
        if (Test-Path $editor.Path) {
            Write-Host "  $($editor.Label) 已有终端字体配置，未修改" -ForegroundColor DarkYellow
        } else {
            Write-Host "  未找到 $($editor.Label) settings.json，跳过" -ForegroundColor DarkYellow
        }
    }
}

# === 完成 ===
Write-Host "`n========================================" -ForegroundColor Green
Write-Host " UTF-8 修复完成!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "已创建的 Wrapper 命令（<命令>u）:" -ForegroundColor Cyan

foreach ($tool in $Script:AiCliTools) {
    $det = $DetectedTools[$tool.Switch]
    if ($det.Installed) {
        $wrap = Get-WrapperCommandName -CommandName $det.Command
        Write-Host "  $wrap -> $($tool.Label) ($($det.Command))" -ForegroundColor White
    }
}

Write-Host ""
Write-Host "使用方式:" -ForegroundColor Cyan
Write-Host "  # 新开终端后运行（务必用 u 后缀命令，例如 codexu / kimiu / agentu）："
Write-Host ""
foreach ($tool in $Script:AiCliTools) {
    $det = $DetectedTools[$tool.Switch]
    if ($det.Installed) {
        Write-Host "  $(Get-WrapperCommandName -CommandName $det.Command)" -ForegroundColor White
    }
}

Write-Host ""
Write-Host "验证 UTF-8:" -ForegroundColor Cyan
Write-Host "  pwsh -Command `"chcp; Write-Host '中文测试 😀'`""

Write-Host ""
Write-Host "若仍乱码:" -ForegroundColor Yellow
Write-Host "  1. Windows Terminal 默认配置文件改为 PowerShell 7 (pwsh)"
Write-Host "  2. 确认用 <命令>u 启动（如 codexu、kimiu、qwenu、kilou、agentu）"
Write-Host "  3. Codex: codex features list 确认 powershell_utf8 已启用"
Write-Host "  4. Claude: ~/.claude/settings.json 中可尝试 USE_POWERSHELL_TOOL=0"
Write-Host "  5. 安装 CJK 字体: Sarasa Gothic / Cascadia Mono"
Write-Host "  6. 仍不行可迁移项目到 WSL2"
