#Requires -Version 5.0

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'FailoverLogic.ps1')
. (Join-Path $PSScriptRoot 'NetworkProbe.ps1')
. (Join-Path $PSScriptRoot 'DesktopShell.ps1')

if (-not (Test-IsWindowsPlatform)) {
    Write-Output 'Удаление работает только в Windows.'
    exit 1
}

$stopped = Stop-DesktopFailoverProcess -ExceptPid $PID
Write-Output "Остановлено процессов: $stopped."

$startup = [Environment]::GetFolderPath('Startup')
if (-not [string]::IsNullOrWhiteSpace($startup)) {
    $launcher = Join-Path $startup 'DesktopFailover.vbs'
    if ([System.IO.File]::Exists($launcher)) {
        [System.IO.File]::Delete($launcher)
        Write-Output "Удалён ярлык автозагрузки: $launcher"
    }
}

try {
    Unregister-ScheduledTask -TaskName 'DesktopFailover' -Confirm:$false -ErrorAction Stop
    Write-Output 'Задача планировщика DesktopFailover удалена.'
} catch {
    Write-Output 'Задача планировщика DesktopFailover не найдена.'
}

$dataDir = Join-Path $env:LOCALAPPDATA 'DesktopFailover'
$statePath = Join-Path $dataDir 'state.json'
$state = Get-EmptyFailoverState
if ([System.IO.File]::Exists($statePath)) {
    try { $state = Read-FailoverState $statePath } catch {}
}
$configPath = Join-Path $dataDir 'config.json'
$config = $null
if ([System.IO.File]::Exists($configPath)) {
    try { $config = Import-FailoverConfig $configPath } catch {}
}

$network = ''
if ($null -ne $config -and -not [string]::IsNullOrWhiteSpace($config.NetworkDesktop)) {
    $network = $config.NetworkDesktop
} elseif (-not [string]::IsNullOrWhiteSpace($state.NetworkDesktop)) {
    $network = $state.NetworkDesktop
}

if ($state.Mode -eq 'Offline' -and -not [string]::IsNullOrWhiteSpace($network)) {
    $expanded = [Environment]::ExpandEnvironmentVariables($network)
    $timeout = 3000
    if ($null -ne $config) { $timeout = [int]$config.ProbeTimeoutMs }
    if (Test-ShareReachable -Path $expanded -TimeoutMs $timeout) {
        Set-DesktopLocation -Path $expanded | Out-Null
        Update-ExplorerDesktop -RestartExplorer $true | Out-Null
        $state.Mode = 'Online'
        Write-FailoverState -State $state -Path $statePath
        Write-Output "Сетевая папка доступна, рабочий стол возвращён: $expanded"
    } else {
        $localPath = '%LOCALAPPDATA%\OfflineDesktop'
        if ($null -ne $config) { $localPath = Resolve-LocalDesktop $config.LocalDesktop }
        Write-Output "Сетевая папка сейчас недоступна, рабочий стол оставлен локальным: $localPath"
        Write-Output "Сетевой путь: $expanded"
    }
} else {
    Write-Output 'Путь рабочего стола не менялся.'
}

$outboxPath = Join-Path $dataDir 'outbox.json'
if ([System.IO.File]::Exists($outboxPath)) {
    Write-Output "Неотправленные заявки лежат в $outboxPath"
}
Write-Output "Файлы программы оставлены в $dataDir"
Write-Output "Локальная копия ярлыков остаётся в папке из localDesktop. Её можно удалить вручную, когда сеть снова работает."
exit 0
