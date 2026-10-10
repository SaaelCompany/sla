#Requires -Version 5.0

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'FailoverLogic.ps1')
. (Join-Path $PSScriptRoot 'DesktopShell.ps1')

function Test-SameDirectory {
    param([string]$Left, [string]$Right)
    $leftPath = [System.IO.Path]::GetFullPath($Left).TrimEnd('\', '/')
    $rightPath = [System.IO.Path]::GetFullPath($Right).TrimEnd('\', '/')
    return $leftPath.Equals($rightPath, [StringComparison]::OrdinalIgnoreCase)
}

function Write-StartupLauncher {
    param(
        [Parameter(Mandatory)][string]$StartupDirectory,
        [Parameter(Mandatory)][string]$ScriptPath
    )
    $launcherPath = Join-Path $StartupDirectory 'DesktopFailover.vbs'
    $escaped = $ScriptPath.Replace('"', '""')
    $content = @"
Set shell = CreateObject("Wscript.Shell")
shell.Run "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File ""$escaped""", 0, False
"@
    $encoding = New-Object System.Text.UnicodeEncoding $false, $true
    [System.IO.File]::WriteAllText($launcherPath, $content.Trim() + [Environment]::NewLine, $encoding)
    return $launcherPath
}

function Register-FailoverLogonTask {
    param([Parameter(Mandatory)][string]$ScriptPath)
    $argument = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$ScriptPath`""
    $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $argument
    $account = $env:USERNAME
    if (-not [string]::IsNullOrWhiteSpace($env:USERDOMAIN)) {
        $account = "$env:USERDOMAIN\$env:USERNAME"
    }
    $trigger = New-ScheduledTaskTrigger -AtLogOn -User $account
    $principal = New-ScheduledTaskPrincipal -UserId $account -LogonType Interactive -RunLevel Limited
    $settings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -MultipleInstances IgnoreNew `
        -RestartCount 3 `
        -RestartInterval (New-TimeSpan -Minutes 1) `
        -ExecutionTimeLimit (New-TimeSpan -Days 3650)
    Register-ScheduledTask `
        -TaskName 'DesktopFailover' `
        -Action $action `
        -Trigger $trigger `
        -Principal $principal `
        -Settings $settings `
        -Description 'Переключение сетевого рабочего стола на локальный, когда сетевая папка недоступна.' `
        -Force | Out-Null
}

if (-not (Test-IsWindowsPlatform)) {
    Write-Output 'Установка работает только в Windows.'
    exit 1
}

$sourceDir = $PSScriptRoot
$targetDir = Join-Path $env:LOCALAPPDATA 'DesktopFailover'
[void][System.IO.Directory]::CreateDirectory($targetDir)

$stopped = Stop-DesktopFailoverProcess -ExceptPid $PID
if ($stopped -gt 0) {
    Write-Output "Остановлена уже запущенная копия: $stopped."
    Start-Sleep -Seconds 1
}

$names = @(
    'DesktopFailover.ps1',
    'FailoverLogic.ps1',
    'NetworkProbe.ps1',
    'DesktopShell.ps1',
    'Install-DesktopFailover.ps1',
    'Uninstall-DesktopFailover.ps1',
    'Start-DesktopFailover.vbs',
    'Install.bat',
    'Uninstall.bat',
    'README.md',
    'config.example.json'
)
if (-not (Test-SameDirectory $sourceDir $targetDir)) {
    foreach ($name in $names) {
        $source = Join-Path $sourceDir $name
        if (-not [System.IO.File]::Exists($source)) { continue }
        Copy-Item -LiteralPath $source -Destination (Join-Path $targetDir $name) -Force
    }
}

$targetConfig = Join-Path $targetDir 'config.json'
$networkShown = ''
if (-not [System.IO.File]::Exists($targetConfig)) {
    $example = Join-Path $targetDir 'config.example.json'
    if (-not [System.IO.File]::Exists($example)) {
        $example = Join-Path $sourceDir 'config.example.json'
    }
    $raw = [System.IO.File]::ReadAllText($example) | ConvertFrom-Json
    $registryDesktop = Get-RegisteredDesktopPath
    if (Test-IsUncPath $registryDesktop) {
        $raw.networkDesktop = $registryDesktop
        $networkShown = $registryDesktop
    }
    $json = $raw | ConvertTo-Json -Depth 4
    $encoding = New-Object System.Text.UTF8Encoding $true
    [System.IO.File]::WriteAllText($targetConfig, $json + [Environment]::NewLine, $encoding)
} else {
    $existing = Import-FailoverConfig $targetConfig
    $networkShown = [string]$existing.NetworkDesktop
    if ([string]::IsNullOrWhiteSpace($networkShown)) {
        $registryDesktop = Get-RegisteredDesktopPath
        if (Test-IsUncPath $registryDesktop) { $networkShown = $registryDesktop }
    }
}

$scriptPath = Join-Path $targetDir 'DesktopFailover.ps1'
$startup = [Environment]::GetFolderPath('Startup')
if ([string]::IsNullOrWhiteSpace($startup)) {
    Write-Output 'Папка автозагрузки недоступна.'
    exit 1
}
$launcher = Write-StartupLauncher -StartupDirectory $startup -ScriptPath $scriptPath
Write-Output "Автозагрузка: $launcher"

try {
    Register-FailoverLogonTask -ScriptPath $scriptPath
    Write-Output 'Задача планировщика DesktopFailover зарегистрирована.'
} catch {
    Write-Output "Задача планировщика не создана: $($_.Exception.Message)"
    Write-Output 'Программа всё равно запустится из автозагрузки.'
}

$argument = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$scriptPath`""
Start-Process -FilePath 'powershell.exe' -ArgumentList $argument -WindowStyle Hidden | Out-Null
Write-Output "Программа запущена. Файлы: $targetDir"

if (-not [string]::IsNullOrWhiteSpace($networkShown)) {
    Write-Output "Сетевой рабочий стол: $networkShown"
} else {
    Write-Output 'Сетевой путь в реестре не найден.'
    Write-Output "Откройте $targetConfig и укажите networkDesktop, например \\server\Common\Desktop"
}
Write-Output 'Проверка без изменений: powershell.exe -NoProfile -ExecutionPolicy Bypass -File "' + $scriptPath + '" -Preview'
exit 0
