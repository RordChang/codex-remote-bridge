param(
    [switch]$Reconfigure,
    [switch]$Background,
    [switch]$CheckOnly,
    [string]$WorkDir = ""
)

$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Write-Ok {
    param([string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-WarnLine {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Write-Fail {
    param([string]$Message)
    Write-Host "[FAIL] $Message" -ForegroundColor Red
}

function Confirm-Action {
    param(
        [string]$Question,
        [bool]$DefaultYes = $false
    )
    $suffix = "[y/N]"
    if ($DefaultYes) {
        $suffix = "[Y/n]"
    }
    $answer = Read-Host "$Question $suffix"
    if ([string]::IsNullOrWhiteSpace($answer)) {
        return $DefaultYes
    }
    return $answer.Trim().ToLowerInvariant() -in @("y", "yes", "是", "好", "确认")
}

function Read-YesNoNever {
    param([string]$Question)
    while ($true) {
        $answer = Read-Host "$Question [y/n/never]"
        $normalized = $answer.Trim().ToLowerInvariant()
        if ($normalized -in @("y", "yes", "是", "好", "确认")) {
            return "yes"
        }
        if ($normalized -in @("n", "no", "否", "不")) {
            return "no"
        }
        if ($normalized -eq "never") {
            return "never"
        }
        Write-WarnLine "Please enter y, n, or never."
    }
}

function Invoke-Logged {
    param(
        [string]$FilePath,
        [string[]]$ArgumentList,
        [string]$WorkingDirectory = $PSScriptRoot
    )
    Write-Host "> $FilePath $($ArgumentList -join ' ')" -ForegroundColor DarkGray
    Push-Location -LiteralPath $WorkingDirectory
    try {
        & $FilePath @ArgumentList
        $exitCode = $LASTEXITCODE
    } finally {
        Pop-Location
    }
    if ($exitCode -ne 0) {
        throw "Command failed with exit code ${exitCode}: $FilePath"
    }
}

function Test-Command {
    param([string]$Name)
    return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Get-TailArgs {
    param([string[]]$Command)
    if ($Command.Count -le 1) {
        return @()
    }
    return $Command[1..($Command.Count - 1)]
}

function Resolve-PythonCommand {
    if (Test-Command "python") {
        try {
            $version = & python --version 2>&1
            if ($LASTEXITCODE -eq 0 -and "$version" -match "Python\s+3\.") {
                return @("python")
            }
        } catch {
        }
    }
    if (Test-Command "py") {
        try {
            $version = & py -3 --version 2>&1
            if ($LASTEXITCODE -eq 0 -and "$version" -match "Python\s+3\.") {
                return @("py", "-3")
            }
        } catch {
        }
    }
    return @()
}

function Invoke-Python {
    param(
        [string[]]$PythonCommand,
        [string[]]$Arguments,
        [string]$WorkingDirectory = $PSScriptRoot
    )
    $exe = $PythonCommand[0]
    $baseArgs = Get-TailArgs -Command $PythonCommand
    Push-Location -LiteralPath $WorkingDirectory
    try {
        & $exe @baseArgs @Arguments
        return $LASTEXITCODE
    } finally {
        Pop-Location
    }
}

function Ensure-WingetPackage {
    param(
        [string]$PackageId,
        [string]$DisplayName
    )
    if (-not (Test-Command "winget")) {
        throw "winget is not available. Please install $DisplayName manually, then rerun this script."
    }
    Invoke-Logged -FilePath "winget" -ArgumentList @("install", "--id", $PackageId, "-e", "--source", "winget", "--accept-package-agreements", "--accept-source-agreements")
}

function Ensure-Python {
    Write-Step "Checking Python"
    $python = @(Resolve-PythonCommand)
    if ($python.Count -gt 0) {
        $exe = $python[0]
        $version = & $exe @(Get-TailArgs -Command $python) --version 2>&1
        Write-Ok "$version"
        return $python
    }

    Write-WarnLine "Python 3 was not found."
    if (Confirm-Action "Install Python 3 with winget now?") {
        Ensure-WingetPackage -PackageId "Python.Python.3.13" -DisplayName "Python 3"
        $python = @(Resolve-PythonCommand)
        if ($python.Count -gt 0) {
            Write-Ok "Python installed"
            return $python
        }
        throw "Python was installed, but this PowerShell session cannot find it yet. Restart PowerShell and rerun this script."
    }
    throw "Python 3 is required."
}

function Ensure-WebsocketClient {
    param([string[]]$PythonCommand)
    Write-Step "Checking Python dependency: websocket-client"
    $code = "import websocket; print(getattr(websocket, '__version__', 'installed'))"
    $exe = $PythonCommand[0]
    $output = & $exe @(Get-TailArgs -Command $PythonCommand) -c $code 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Ok "websocket-client $output"
        return
    }

    Write-WarnLine "Python package websocket-client is missing."
    if (Confirm-Action "Install websocket-client for the current user now?") {
        Invoke-Python -PythonCommand $PythonCommand -Arguments @("-m", "pip", "install", "--user", "websocket-client") | Out-Null
        $output = & $exe @(Get-TailArgs -Command $PythonCommand) -c $code 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Ok "websocket-client $output"
            return
        }
        throw "websocket-client installation did not pass the import check."
    }
    throw "websocket-client is required."
}

function Ensure-NodeAndNpm {
    Write-Step "Checking Node.js and npm"
    if (Test-Command "node" -and Test-Command "npm") {
        $nodeVersion = & node --version 2>&1
        $npmVersion = & npm --version 2>&1
        Write-Ok "node $nodeVersion; npm $npmVersion"
        return
    }

    Write-WarnLine "Node.js/npm was not found. It is needed to install the npm Codex CLI fallback."
    if (Confirm-Action "Install Node.js LTS with winget now?") {
        Ensure-WingetPackage -PackageId "OpenJS.NodeJS.LTS" -DisplayName "Node.js LTS"
        if (Test-Command "node" -and Test-Command "npm") {
            Write-Ok "Node.js/npm installed"
            return
        }
        throw "Node.js was installed, but this PowerShell session cannot find npm yet. Restart PowerShell and rerun this script."
    }
    throw "npm is required when no runnable Codex CLI is available."
}

function Test-ExecutableVersion {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $false
    }
    try {
        $result = & $Path --version 2>&1
        if ($LASTEXITCODE -eq 0 -and "$result".Trim()) {
            Write-Ok "Codex CLI: $Path ($result)"
            return $true
        }
    } catch {
    }
    return $false
}

function Resolve-CodexCommand {
    $appDataCodex = Join-Path $env:APPDATA "npm\codex.cmd"
    if (Test-Path -LiteralPath $appDataCodex) {
        if (Test-ExecutableVersion -Path $appDataCodex) {
            return $appDataCodex
        }
    }

    $codexCmd = Get-Command "codex.cmd" -ErrorAction SilentlyContinue
    if ($codexCmd -and (Test-ExecutableVersion -Path $codexCmd.Source)) {
        return $codexCmd.Source
    }

    if (Test-Command "npm") {
        try {
            $npmPrefix = (& npm prefix -g 2>$null).Trim()
            if ($LASTEXITCODE -eq 0 -and $npmPrefix) {
                $npmCodex = Join-Path $npmPrefix "codex.cmd"
                if (Test-Path -LiteralPath $npmCodex) {
                    if (Test-ExecutableVersion -Path $npmCodex) {
                        return $npmCodex
                    }
                }
            }
        } catch {
        }
    }

    $codex = Get-Command "codex" -ErrorAction SilentlyContinue
    if ($codex -and (Test-ExecutableVersion -Path $codex.Source)) {
        return $codex.Source
    }

    return ""
}

function Ensure-CodexCli {
    Write-Step "Checking Codex CLI"
    $codexCommand = Resolve-CodexCommand
    if ($codexCommand) {
        return $codexCommand
    }

    Write-WarnLine "No runnable Codex CLI was found."
    Write-WarnLine "If WindowsApps codex.exe returns Access is denied, this script can install the npm CLI instead."
    Ensure-NodeAndNpm
    if (Confirm-Action "Install @openai/codex globally with npm now?") {
        Invoke-Logged -FilePath "npm" -ArgumentList @("install", "-g", "@openai/codex")
        $codexCommand = Resolve-CodexCommand
        if ($codexCommand) {
            return $codexCommand
        }
        throw "@openai/codex installed, but no runnable codex command was found. Check npm global prefix and PATH."
    }
    throw "A runnable Codex CLI is required."
}

function Read-EnvFile {
    param([string]$Path)
    $map = [ordered]@{}
    if (-not (Test-Path -LiteralPath $Path)) {
        return $map
    }
    foreach ($line in Get-Content -LiteralPath $Path -Encoding UTF8) {
        $trimmed = $line.Trim()
        if (-not $trimmed -or $trimmed.StartsWith("#") -or -not $trimmed.Contains("=")) {
            continue
        }
        $key, $value = $trimmed.Split("=", 2)
        $map[$key.Trim()] = $value.Trim().Trim('"').Trim("'")
    }
    return $map
}

function Get-EnvValue {
    param(
        [hashtable]$Map,
        [string]$Key,
        [string]$DefaultValue
    )
    if ($Map.Contains($Key) -and -not [string]::IsNullOrWhiteSpace([string]$Map[$Key])) {
        return [string]$Map[$Key]
    }
    return $DefaultValue
}

function Test-ConfiguredValue {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $false
    }
    return -not ($Value.Trim().ToLowerInvariant().StartsWith("replace-"))
}

function Read-SecretPlainText {
    param([string]$Prompt)
    $secure = Read-Host $Prompt -AsSecureString
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    } finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
}

function Write-ConfigHelp {
    Write-Host ""
    Write-Host "QQ Bot AppID / AppSecret 获取方式：" -ForegroundColor Yellow
    Write-Host "申请入口：https://q.qq.com/#/"
    Write-Host "1. 打开 QQ 官方机器人/开放平台后台：https://q.qq.com/#/"
    Write-Host "2. 创建或选择你的 Bot 应用。"
    Write-Host "3. 在开发设置、基础信息或凭据页面复制 AppID 和 AppSecret。"
    Write-Host "4. 确认机器人启用了 Gateway 事件，并至少允许 C2C_MESSAGE_CREATE 或 GROUP_AT_MESSAGE_CREATE。"
    Write-Host "5. 如需按钮卡片，再启用 INTERACTION_CREATE，并在 .env 中加入对应事件。"
    Write-Host "注意：这里不需要、也不应该输入个人 QQ 账号密码。"
}

function Write-EnvFile {
    param(
        [string]$Path,
        [hashtable]$Existing,
        [string]$CodexCommand,
        [string]$CodexWorkdir,
        [string]$AppId,
        [string]$AppSecret
    )

    $lines = @(
        "CODEX_COMMAND=$CodexCommand",
        "CODEX_WORKDIR=$CodexWorkdir",
        "CODEX_MODEL=$(Get-EnvValue -Map $Existing -Key 'CODEX_MODEL' -DefaultValue 'gpt-5.5')",
        "CODEX_REASONING_EFFORT=$(Get-EnvValue -Map $Existing -Key 'CODEX_REASONING_EFFORT' -DefaultValue 'xhigh')",
        "CODEX_PERMISSION=$(Get-EnvValue -Map $Existing -Key 'CODEX_PERMISSION' -DefaultValue 'read-only')",
        "CODEX_CONTEXT_MODE=$(Get-EnvValue -Map $Existing -Key 'CODEX_CONTEXT_MODE' -DefaultValue 'native')",
        "CODEX_ALLOWED_MODELS=$(Get-EnvValue -Map $Existing -Key 'CODEX_ALLOWED_MODELS' -DefaultValue 'gpt-5.5,gpt-5.4')",
        "CODEX_TIMEOUT_SECONDS=$(Get-EnvValue -Map $Existing -Key 'CODEX_TIMEOUT_SECONDS' -DefaultValue '1800')",
        "MAX_HISTORY_CHARS=$(Get-EnvValue -Map $Existing -Key 'MAX_HISTORY_CHARS' -DefaultValue '12000')",
        "",
        "# QQ official Gateway mode.",
        "# C2C and group @ messages usually use 1<<25.",
        "# Add INTERACTION_CREATE when Markdown/Keyboard buttons are enabled.",
        "QQ_APP_ID=$AppId",
        "QQ_APP_SECRET=$AppSecret",
        "QQ_API_BASE=$(Get-EnvValue -Map $Existing -Key 'QQ_API_BASE' -DefaultValue 'https://api.sgroup.qq.com')",
        "QQ_AUTH_URL=$(Get-EnvValue -Map $Existing -Key 'QQ_AUTH_URL' -DefaultValue 'https://bots.qq.com/app/getAppAccessToken')",
        "QQ_GATEWAY_PATH=$(Get-EnvValue -Map $Existing -Key 'QQ_GATEWAY_PATH' -DefaultValue '/gateway')",
        "QQ_GATEWAY_INTENTS=$(Get-EnvValue -Map $Existing -Key 'QQ_GATEWAY_INTENTS' -DefaultValue '33554432')",
        "QQ_ALLOWED_EVENTS=$(Get-EnvValue -Map $Existing -Key 'QQ_ALLOWED_EVENTS' -DefaultValue 'C2C_MESSAGE_CREATE,GROUP_AT_MESSAGE_CREATE')",
        "QQ_REPLY_MAX_CHARS=$(Get-EnvValue -Map $Existing -Key 'QQ_REPLY_MAX_CHARS' -DefaultValue '1500')",
        "QQ_MAX_REPLY_CHUNKS=$(Get-EnvValue -Map $Existing -Key 'QQ_MAX_REPLY_CHUNKS' -DefaultValue '5')",
        "QQ_SEND_PROCESSING_MESSAGE=$(Get-EnvValue -Map $Existing -Key 'QQ_SEND_PROCESSING_MESSAGE' -DefaultValue '1')",
        "QQ_PROCESSING_TEXT=$(Get-EnvValue -Map $Existing -Key 'QQ_PROCESSING_TEXT' -DefaultValue 'Received, processing.')",
        "QQ_SEND_STARTUP_TO_ALLOWED_USERS=$(Get-EnvValue -Map $Existing -Key 'QQ_SEND_STARTUP_TO_ALLOWED_USERS' -DefaultValue '1')",
        "QQ_ATTACHMENT_DOWNLOAD=$(Get-EnvValue -Map $Existing -Key 'QQ_ATTACHMENT_DOWNLOAD' -DefaultValue '1')",
        "QQ_ATTACHMENT_MAX_COUNT=$(Get-EnvValue -Map $Existing -Key 'QQ_ATTACHMENT_MAX_COUNT' -DefaultValue '4')",
        "QQ_ATTACHMENT_MAX_BYTES=$(Get-EnvValue -Map $Existing -Key 'QQ_ATTACHMENT_MAX_BYTES' -DefaultValue '26214400')",
        "QQ_RESTART_DELAY_SECONDS=$(Get-EnvValue -Map $Existing -Key 'QQ_RESTART_DELAY_SECONDS' -DefaultValue '2')",
        "",
        "# Optional labels and allowlists.",
        "# Send /whoami to the bot first, then put user_openid into QQ_ALLOWED_USER_OPENIDS.",
        "# Leave allowlists empty only when every reachable user/group may use the bot.",
        "QQ_OWNER_QQ=$(Get-EnvValue -Map $Existing -Key 'QQ_OWNER_QQ' -DefaultValue '')",
        "QQ_ALLOWED_USER_OPENIDS=$(Get-EnvValue -Map $Existing -Key 'QQ_ALLOWED_USER_OPENIDS' -DefaultValue '')",
        "QQ_ALLOWED_GROUP_OPENIDS=$(Get-EnvValue -Map $Existing -Key 'QQ_ALLOWED_GROUP_OPENIDS' -DefaultValue '')"
    )

    Set-Content -LiteralPath $Path -Value $lines -Encoding UTF8
}

function Ensure-EnvConfig {
    param(
        [string]$EnvPath,
        [string]$CodexCommand,
        [string]$DefaultWorkdir
    )

    Write-Step "Checking bridge configuration"
    $existing = Read-EnvFile -Path $EnvPath
    $appId = Get-EnvValue -Map $existing -Key "QQ_APP_ID" -DefaultValue "replace-with-qq-app-id"
    $appSecret = Get-EnvValue -Map $existing -Key "QQ_APP_SECRET" -DefaultValue "replace-with-qq-app-secret"
    $codexWorkdir = Get-EnvValue -Map $existing -Key "CODEX_WORKDIR" -DefaultValue $DefaultWorkdir

    $needsCredentials = $Reconfigure -or -not (Test-ConfiguredValue $appId) -or -not (Test-ConfiguredValue $appSecret)
    if ($needsCredentials) {
        Write-ConfigHelp
        $inputAppId = Read-Host "请输入 QQ_APP_ID"
        if (-not [string]::IsNullOrWhiteSpace($inputAppId)) {
            $appId = $inputAppId.Trim()
        }
        $inputSecret = Read-SecretPlainText -Prompt "请输入 QQ_APP_SECRET（输入时不会显示）"
        if (-not [string]::IsNullOrWhiteSpace($inputSecret)) {
            $appSecret = $inputSecret.Trim()
        }
    }

    if ($Reconfigure -or -not (Test-ConfiguredValue $codexWorkdir)) {
        $answer = Read-Host "Codex 工作目录 [$codexWorkdir]"
        if (-not [string]::IsNullOrWhiteSpace($answer)) {
            $codexWorkdir = $answer.Trim()
        }
    }

    if (-not (Test-ConfiguredValue $appId) -or -not (Test-ConfiguredValue $appSecret)) {
        throw "QQ_APP_ID and QQ_APP_SECRET must be configured before the bridge can connect to QQ Gateway."
    }

    Write-EnvFile -Path $EnvPath -Existing $existing -CodexCommand $CodexCommand -CodexWorkdir $codexWorkdir -AppId $appId -AppSecret $appSecret
    Write-Ok "Configuration saved to $EnvPath"
    Write-Host "Configured summary:"
    Write-Host "  CODEX_COMMAND=$CodexCommand"
    Write-Host "  CODEX_WORKDIR=$codexWorkdir"
    Write-Host "  QQ_APP_ID=$appId"
    Write-Host "  QQ_APP_SECRET=(hidden)"
}

function Read-DeployPreferences {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        return @{}
    }
    try {
        $json = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
        $map = @{}
        foreach ($property in $json.PSObject.Properties) {
            $map[$property.Name] = $property.Value
        }
        return $map
    } catch {
        Write-WarnLine "Could not read deploy preferences; ignoring: $Path"
        return @{}
    }
}

function Write-DeployPreferences {
    param(
        [string]$Path,
        [hashtable]$Preferences
    )
    $dir = Split-Path -Parent $Path
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $Preferences | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Test-AutostartTaskConfigured {
    param(
        [string]$TaskName,
        [string]$AutostartScript
    )
    if (-not (Test-Path -LiteralPath $AutostartScript)) {
        return $false
    }

    try {
        $expectedScript = (Resolve-Path -LiteralPath $AutostartScript).Path
        $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
        if ($null -eq $task) {
            return $false
        }
        if ([string]$task.State -eq "Disabled") {
            return $false
        }

        $hasExpectedAction = $false
        foreach ($action in @($task.Actions)) {
            $arguments = [string]$action.Arguments
            if ($arguments.IndexOf($expectedScript, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
                $hasExpectedAction = $true
                break
            }
        }
        if (-not $hasExpectedAction) {
            return $false
        }

        $enabledTriggers = @($task.Triggers | Where-Object { $_.Enabled -ne $false })
        return $enabledTriggers.Count -gt 0
    } catch {
        Write-WarnLine "Could not verify autostart task; will ask again: $($_.Exception.Message)"
        return $false
    }
}

function Ensure-AutostartTask {
    param(
        [string]$TaskName,
        [string]$AutostartScript
    )
    if (-not (Test-Path -LiteralPath $AutostartScript)) {
        throw "Cannot find autostart script: $AutostartScript"
    }

    Write-Step "Configuring Windows autostart"
    $powershellPath = Join-Path $PSHOME "powershell.exe"
    if (-not (Test-Path -LiteralPath $powershellPath)) {
        $powershellPath = "powershell.exe"
    }

    $action = New-ScheduledTaskAction `
        -Execute $powershellPath `
        -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$AutostartScript`""
    $trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
    $settings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -MultipleInstances IgnoreNew `
        -ExecutionTimeLimit (New-TimeSpan -Days 0)

    Register-ScheduledTask `
        -TaskName $TaskName `
        -Action $action `
        -Trigger $trigger `
        -Settings $settings `
        -Description "Start Codex Remote Bridge at user logon." `
        -Force | Out-Null

    Write-Ok "Autostart task configured: $TaskName"
    Write-Host "  Script: $AutostartScript"
}

function Maybe-ConfigureAutostart {
    param(
        [string]$PreferencesPath,
        [string]$AutostartScript
    )
    $taskName = "CodexRemoteBridge"
    if (Test-AutostartTaskConfigured -TaskName $taskName -AutostartScript $AutostartScript) {
        Write-Ok "Autostart task is already enabled for this project; skipping autostart prompt."
        return
    }

    $preferences = Read-DeployPreferences -Path $PreferencesPath
    if ([string]$preferences["autostart_prompt"] -eq "never") {
        Write-Ok "Autostart prompt skipped because you previously chose never."
        return
    }

    $choice = Read-YesNoNever -Question "是否要配置 Windows 登录后自启动 Codex Remote Bridge？"
    if ($choice -eq "never") {
        $preferences["autostart_prompt"] = "never"
        Write-DeployPreferences -Path $PreferencesPath -Preferences $preferences
        Write-Ok "Saved preference: do not ask about autostart again."
        return
    }
    if ($choice -eq "no") {
        Write-Host "This run will not configure autostart. The script will ask again next time."
        return
    }

    Ensure-AutostartTask -TaskName $taskName -AutostartScript $AutostartScript
}

function Show-QuickStartHelp {
    param(
        [string]$LogFile,
        [bool]$IsBackground
    )
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host "  启动后会尝试向已认证用户发送 /start，也可手动发送 /start" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "桥接器启动后的快速入门：" -ForegroundColor Cyan
    Write-Host "1. 给机器人发送 /start，查看当前 model、reasoning 和快捷按钮。"
    Write-Host "2. 给机器人发送 /status，确认 Gateway、模型、思考强度和权限模式。"
    Write-Host "3. 给机器人发送 /whoami，获取你的 user_openid。"
    Write-Host "4. 如果要限制访问，把 user_openid 写入 client\.env 的 QQ_ALLOWED_USER_OPENIDS，然后重启。"
    Write-Host "5. 给机器人发送 /help，可以随时查看完整命令。"
    Write-Host "6. 直接发送普通消息，即可通过这个桥接器调用 Codex。"
    Write-Host "7. 如果 client\.env 已配置 QQ_ALLOWED_USER_OPENIDS，启动时会主动给这些用户发送 /start。"
    Write-Host "8. 每次桥接器启动后，每个 QQ 联系来源首次发消息时，机器人也会自动返回一次 /start。"
    Write-Host ""
    Write-Host "常用命令："
    Write-Host "  /start                        显示入口面板和快捷按钮"
    Write-Host "  /help                         显示所有命令"
    Write-Host "  /status                       显示桥接器状态"
    Write-Host "  /whoami                       显示当前 QQ Gateway openid"
    Write-Host "  /model                        显示当前模型和思考强度"
    Write-Host "  /model gpt-5.5 high           设置模型和思考强度"
    Write-Host "  /permission                   显示权限模式"
    Write-Host "  /timeout 45                   设置单次 Codex 调用超时为 45 分钟"
    Write-Host "  /permission read only         使用只读模式"
    Write-Host "  /permission ask               高风险操作前请求批准"
    Write-Host "  /pending                      显示待批准操作"
    Write-Host "  /allow <id>                   批准待执行操作"
    Write-Host "  /cancel                       取消当前 Codex 任务"
    Write-Host "  /restart                      重启 QQ Gateway 客户端"
    Write-Host "  /resume                       列出 Codex 原生会话"
    Write-Host "  /new [标题]                   开启新的 Codex 会话"
    if ($IsBackground) {
        Write-Host ""
        Write-Host "后台日志："
        Write-Host "  $LogFile"
    } else {
        Write-Host ""
        Write-Host "前台模式：保持这个 PowerShell 窗口打开。按 Ctrl+C 停止。"
    }
}

function Get-BridgeProcesses {
    param([string]$ClientDir)
    $resolvedClientDir = (Resolve-Path -LiteralPath $ClientDir).Path
    $escapedClientDir = [regex]::Escape($resolvedClientDir)
    $currentPid = $PID

    Get-CimInstance Win32_Process |
        Where-Object {
            $_.ProcessId -ne $currentPid -and
            $_.Name -match '^(python|pythonw|py)\.exe$' -and
            $_.CommandLine -and
            $_.CommandLine -match $escapedClientDir -and
            ($_.CommandLine -match 'qq_gateway_client\.py' -or $_.CommandLine -match 'qq_gateway_background\.py')
        } |
        Select-Object ProcessId, Name, CommandLine
}

function Stop-BridgeProcessTree {
    param(
        [int]$ProcessId,
        [string]$Label
    )
    $output = & taskkill.exe /PID $ProcessId /T /F 2>&1
    if ($LASTEXITCODE -ne 0) {
        $stillRunning = Get-CimInstance Win32_Process -Filter "ProcessId = $ProcessId" -ErrorAction SilentlyContinue
        if ($stillRunning) {
            throw "无法终止 $Label PID ${ProcessId}: $output"
        }
        Write-Ok "$Label PID $ProcessId 已退出"
        return
    }
    Write-Ok "已终止 $Label 进程树 PID $ProcessId"
}

function Resolve-ForegroundProcessConflict {
    param([string]$ClientDir)
    $processes = @(Get-BridgeProcesses -ClientDir $ClientDir)
    if ($processes.Count -eq 0) {
        return
    }

    Write-Host ""
    Write-Fail "检测到已有后台 Codex Remote Bridge 进程正在运行。"
    foreach ($process in $processes) {
        Write-Host "  PID $($process.ProcessId): $($process.CommandLine)"
    }

    while ($true) {
        $answer = Read-Host "选择操作：输入 y 终止这些后台进程并继续前台启动；输入 n 停止本次前台运行 [y/n]"
        $normalized = $answer.Trim().ToLowerInvariant()
        if ($normalized -in @("y", "yes", "是", "好", "确认")) {
            $supervisors = @($processes | Where-Object { $_.CommandLine -match 'qq_gateway_background\.py' })
            $clients = @($processes | Where-Object { $_.CommandLine -match 'qq_gateway_client\.py' })

            foreach ($process in $supervisors) {
                Stop-BridgeProcessTree -ProcessId $process.ProcessId -Label "supervisor"
            }

            Start-Sleep -Seconds 1
            $remaining = @(Get-BridgeProcesses -ClientDir $ClientDir)
            $remainingClients = @($remaining | Where-Object { $_.CommandLine -match 'qq_gateway_client\.py' })
            foreach ($process in $remainingClients) {
                Stop-BridgeProcessTree -ProcessId $process.ProcessId -Label "client"
            }

            $remaining = @(Get-BridgeProcesses -ClientDir $ClientDir)
            if ($remaining.Count -gt 0) {
                foreach ($process in $remaining) {
                    Write-WarnLine "仍检测到进程 PID $($process.ProcessId): $($process.CommandLine)"
                }
                throw "仍有 Codex Remote Bridge 进程未退出，请手动检查后再前台启动。"
            }
            Start-Sleep -Seconds 1
            return
        }
        if ($normalized -in @("n", "no", "否", "不", "")) {
            throw "已停止前台启动；后台 bridge 仍在运行。"
        }
        Write-WarnLine "请输入 y 或 n。"
    }
}

function Start-BridgeForeground {
    param(
        [string[]]$PythonCommand,
        [string]$ClientDir
    )
    Resolve-ForegroundProcessConflict -ClientDir $ClientDir
    Write-Step "Starting QQ Gateway bridge in foreground"
    Write-Host "Press Ctrl+C to stop."
    Invoke-Python -PythonCommand $PythonCommand -Arguments @(".\qq_gateway_client.py") -WorkingDirectory $ClientDir | Out-Null
}

function Start-BridgeBackground {
    param(
        [string[]]$PythonCommand,
        [string]$ClientDir,
        [string]$LogFile
    )
    Write-Step "Starting QQ Gateway bridge in background"
    $exe = $PythonCommand[0]
    $args = @(Get-TailArgs -Command $PythonCommand)
    $args += @("-B", (Join-Path $ClientDir "qq_gateway_background.py"))
    Start-Process -FilePath $exe -ArgumentList $args -WorkingDirectory $ClientDir -WindowStyle Hidden | Out-Null
    Start-Sleep -Seconds 3
    Write-Ok "Background supervisor started"
    if (Test-Path -LiteralPath $LogFile) {
        Write-Host ""
        Write-Host "Recent log: $LogFile" -ForegroundColor Cyan
        Get-Content -LiteralPath $LogFile -Tail 80 -Encoding UTF8
    } else {
        Write-WarnLine "Log file has not been created yet: $LogFile"
    }
}

if (-not $IsWindows -and $PSVersionTable.PSEdition -eq "Core") {
    throw "This script is for Windows only."
}

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$clientDir = Join-Path $root "client"
$envPath = Join-Path $clientDir ".env"
$dataDir = Join-Path $clientDir "data"
$logFile = Join-Path $dataDir "qq-gateway-autostart.log"
$preferencesPath = Join-Path $dataDir "deploy-preferences.json"
$autostartScript = Join-Path $clientDir "start-bridge-autostart.ps1"

if (-not (Test-Path -LiteralPath $clientDir)) {
    throw "Cannot find client directory: $clientDir"
}

if ([string]::IsNullOrWhiteSpace($WorkDir)) {
    $WorkDir = $root
}

New-Item -ItemType Directory -Force -Path $dataDir | Out-Null

Write-Host "Codex Remote Bridge Windows deploy script" -ForegroundColor Cyan
Write-Host "Project: $root"

$python = @(Ensure-Python)
Ensure-WebsocketClient -PythonCommand $python
$codexCommand = Ensure-CodexCli
Ensure-EnvConfig -EnvPath $envPath -CodexCommand $codexCommand -DefaultWorkdir $WorkDir

Write-Step "Validating Python files and local commands"
Invoke-Python -PythonCommand $python -Arguments @("-m", "py_compile", "codex_bridge_client.py", "qq_gateway_client.py", "qq_gateway_background.py") -WorkingDirectory $clientDir | Out-Null
Invoke-Python -PythonCommand $python -Arguments @("-c", "from codex_bridge_client import handle_bridge_command; print(handle_bridge_command('/status'))") -WorkingDirectory $clientDir | Out-Null
Write-Ok "Local validation passed"

if ($CheckOnly) {
    Write-Step "Check only mode"
    Write-Host "Configuration and local validation are complete."
    Write-Host "Run foreground:"
    Write-Host "  powershell -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`""
    Write-Host "Run background:"
    Write-Host "  powershell -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`" -Background"
    exit 0
}

Maybe-ConfigureAutostart -PreferencesPath $preferencesPath -AutostartScript $autostartScript

if ($Background) {
    Show-QuickStartHelp -LogFile $logFile -IsBackground $true
    Start-BridgeBackground -PythonCommand $python -ClientDir $clientDir -LogFile $logFile
} else {
    Show-QuickStartHelp -LogFile $logFile -IsBackground $false
    Start-BridgeForeground -PythonCommand $python -ClientDir $clientDir
}
