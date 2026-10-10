#Requires -Version 5.0

param(
    [switch]$Once,
    [switch]$Status,
    [switch]$Preview,
    [string]$ConfigPath,
    [string]$StatePath,
    [string]$LogPath
)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'FailoverLogic.ps1')
. (Join-Path $PSScriptRoot 'NetworkProbe.ps1')
. (Join-Path $PSScriptRoot 'DesktopShell.ps1')

function Get-FailoverDataDirectory {
    if (-not [string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
        return Join-Path $env:LOCALAPPDATA 'DesktopFailover'
    }
    return $PSScriptRoot
}

function Resolve-MonitorLocations {
    param(
        [string]$ConfigPath,
        [string]$StatePath,
        [string]$LogPath
    )
    $data = Get-FailoverDataDirectory
    [void][System.IO.Directory]::CreateDirectory($data)
    $resolvedConfig = $ConfigPath
    if ([string]::IsNullOrWhiteSpace($resolvedConfig)) {
        $beside = Join-Path $PSScriptRoot 'config.json'
        $inData = Join-Path $data 'config.json'
        if ([System.IO.File]::Exists($beside)) {
            $resolvedConfig = $beside
        } elseif ([System.IO.File]::Exists($inData)) {
            $resolvedConfig = $inData
        } else {
            $resolvedConfig = $beside
        }
    }
    if ([string]::IsNullOrWhiteSpace($StatePath)) {
        $StatePath = Join-Path $data 'state.json'
    }
    if ([string]::IsNullOrWhiteSpace($LogPath)) {
        $LogPath = Join-Path $data 'desktop-failover.log'
    }
    [pscustomobject]@{
        ConfigPath = $resolvedConfig
        StatePath = $StatePath
        LogPath = $LogPath
        DataDirectory = $data
    }
}

function Write-FailoverLog {
    param(
        [string]$Message,
        [string]$Path
    )
    if ([string]::IsNullOrWhiteSpace($Path) -or [string]::IsNullOrWhiteSpace($Message)) { return }
    $directory = [System.IO.Path]::GetDirectoryName($Path)
    if (-not [string]::IsNullOrWhiteSpace($directory)) {
        [void][System.IO.Directory]::CreateDirectory($directory)
    }
    if ([System.IO.File]::Exists($Path) -and (Get-Item -LiteralPath $Path).Length -gt 1MB) {
        $backup = "$Path.old"
        if ([System.IO.File]::Exists($backup)) { [System.IO.File]::Delete($backup) }
        [System.IO.File]::Move($Path, $backup)
    }
    $clean = ($Message -replace '[\r\n]+', ' ').Trim()
    $line = '{0:yyyy-MM-dd HH:mm:ss} {1}' -f (Get-Date), $clean
    $payload = $line + [Environment]::NewLine
    if (-not [System.IO.File]::Exists($Path)) {
        $withBom = New-Object System.Text.UTF8Encoding $true
        [System.IO.File]::WriteAllText($Path, $payload, $withBom)
        return
    }
    $withoutBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::AppendAllText($Path, $payload, $withoutBom)
}

function Get-LiveProbe {
    param($Config, $State)
    $registry = Get-RegisteredDesktopPath
    $networkGuess = Resolve-NetworkDesktop -Configured $Config.NetworkDesktop -Remembered $State.NetworkDesktop -RegistryValue $registry
    $shareUp = $false
    $internetUp = $true
    if (-not [string]::IsNullOrWhiteSpace($networkGuess)) {
        $expanded = [Environment]::ExpandEnvironmentVariables($networkGuess)
        $shareUp = Test-ShareReachable -Path $expanded -TimeoutMs $Config.ProbeTimeoutMs
    }
    if ($Config.ProbeMode -ne 'share') {
        $internetUp = Test-InternetAccess -Urls $Config.InternetProbes -TimeoutMs $Config.ProbeTimeoutMs
    }
    [pscustomobject]@{
        Registry = $registry
        ShareUp = [bool]$shareUp
        InternetUp = [bool]$internetUp
    }
}

function Show-FailoverStatus {
    param($Locations)
    $config = Import-FailoverConfig $Locations.ConfigPath
    $state = Read-FailoverState $Locations.StatePath
    $probe = Get-LiveProbe -Config $config -State $state
    $result = Invoke-FailoverCycle -Config $config -State $state -RegistryDesktop $probe.Registry -ShareUp $probe.ShareUp -InternetUp $probe.InternetUp
    $probeStatus = Format-ProbeStatus -ProbeMode $config.ProbeMode -ShareUp $probe.ShareUp -InternetUp $probe.InternetUp
    Write-Output "DesktopFailover $(Get-DesktopFailoverVersion)"
    Write-Output "Конфиг: $($Locations.ConfigPath)"
    Write-Output "Состояние: $($Locations.StatePath)"
    Write-Output "Журнал: $($Locations.LogPath)"
    if ($result.Ok) {
        Write-Output "Режим: $($result.State.Mode)"
        Write-Output "Сетевой рабочий стол: $($result.NetworkDesktop)"
        Write-Output "Локальный рабочий стол: $($result.LocalDesktop)"
        Write-Output "Сейчас в реестре: $($probe.Registry)"
        Write-Output $probeStatus
        Write-Output "Неудачные проверки подряд: $($result.State.ConsecutiveFailures) из $($config.FailureThreshold)"
        Write-Output "Успешные проверки подряд: $($result.State.ConsecutiveSuccesses) из $($config.RecoveryThreshold)"
    } else {
        Write-Output $result.Message
    }
    if (-not [string]::IsNullOrWhiteSpace($state.LastSyncUtc)) {
        Write-Output "Последняя синхронизация (UTC): $($state.LastSyncUtc)"
    }
    if (-not [string]::IsNullOrWhiteSpace($state.LastProbeUtc)) {
        Write-Output "Последний сохранённый цикл (UTC): $($state.LastProbeUtc)"
    }
    if ([System.IO.File]::Exists($Locations.LogPath)) {
        $lines = [System.IO.File]::ReadAllLines($Locations.LogPath)
        $start = [Math]::Max(0, $lines.Length - 8)
        Write-Output 'Последние записи журнала:'
        for ($index = $start; $index -lt $lines.Length; $index++) {
            Write-Output $lines[$index]
        }
    }
    if ($result.Ok) { exit 0 }
    exit 1
}

function Show-FailoverPreview {
    param($Locations)
    $config = Import-FailoverConfig $Locations.ConfigPath
    $state = Read-FailoverState $Locations.StatePath
    $probe = Get-LiveProbe -Config $config -State $state
    $result = Invoke-FailoverCycle -Config $config -State $state -RegistryDesktop $probe.Registry -ShareUp $probe.ShareUp -InternetUp $probe.InternetUp
    $probeStatus = Format-ProbeStatus -ProbeMode $config.ProbeMode -ShareUp $probe.ShareUp -InternetUp $probe.InternetUp
    Write-Output (Format-PreviewReport -Result $result -ProbeStatus $probeStatus)
    if ($result.Ok) { exit 0 }
    exit 1
}

function Invoke-MonitorCycle {
    param($Config, $State)
    $probe = Get-LiveProbe -Config $Config -State $State
    $result = Invoke-FailoverCycle -Config $Config -State $State -RegistryDesktop $probe.Registry -ShareUp $probe.ShareUp -InternetUp $probe.InternetUp
    $probeStatus = Format-ProbeStatus -ProbeMode $Config.ProbeMode -ShareUp $probe.ShareUp -InternetUp $probe.InternetUp
    $logs = New-Object System.Collections.Generic.List[string]

    if (-not $result.Ok) {
        $logs.Add([string]$result.Message)
        return [pscustomobject]@{ Result = $result; Logs = $logs }
    }

    if ($result.State.ConsecutiveFailures -eq 1 -and -not $result.Switched) {
        $logs.Add("Проверка не прошла ($probeStatus). Жду повтор перед переключением на локальный рабочий стол.")
    }
    if ($result.State.ConsecutiveSuccesses -eq 1 -and -not $result.Switched) {
        $logs.Add("Проверка снова успешна ($probeStatus). Жду повтор перед возвратом сетевого рабочего стола.")
    }

    if ($result.ShouldSyncBack) {
        $back = Sync-TreeOneWay -Source $result.LocalDesktop -Destination $result.NetworkDesktop -MaxFileBytes $Config.MaxFileBytes
        if ($back.Copied -gt 0 -or $back.Errors.Count -gt 0) {
            $logs.Add("Возврат локальных изменений: скопировано $($back.Copied), ошибок $($back.Errors.Count).")
            foreach ($errorLine in @($back.Errors | Select-Object -First 5)) {
                $logs.Add($errorLine)
            }
        }
    }

    if ($result.ShouldSync) {
        $previousSync = [string]$result.State.LastSyncUtc
        $sync = Sync-TreeOneWay -Source $result.NetworkDesktop -Destination $result.LocalDesktop -MaxFileBytes $Config.MaxFileBytes
        $result.State.LastSyncUtc = [datetime]::UtcNow.ToString('o')
        $firstSync = [string]::IsNullOrWhiteSpace($previousSync)
        if ($sync.Copied -gt 0 -or $sync.Errors.Count -gt 0 -or ($firstSync -and $sync.Skipped -gt 0)) {
            $logs.Add("Синхронизация: скопировано $($sync.Copied), пропущено $($sync.Skipped), ошибок $($sync.Errors.Count).")
            foreach ($errorLine in @($sync.Errors | Select-Object -First 5)) {
                $logs.Add($errorLine)
            }
        }
    }

    if ($result.ShouldApply) {
        if ($result.State.Mode -eq 'Offline' -and (Test-IsRemoteDrive $result.LocalDesktop)) {
            $logs.Add("Локальный путь $($result.LocalDesktop) находится на сетевом диске. Укажите папку на диске этого компьютера.")
        } else {
            $applied = Set-DesktopLocation -Path $result.DesiredDesktop
            $restart = $false
            if ($Config.RestartExplorer -and (Test-IntervalElapsed -LastUtc $result.State.LastExplorerRestartUtc -IntervalSeconds $Config.ExplorerRestartCooldownSeconds)) {
                $restart = $true
            }
            $explorer = Update-ExplorerDesktop -RestartExplorer $restart
            if ($restart) {
                $result.State.LastExplorerRestartUtc = [datetime]::UtcNow.ToString('o')
            }
            $cacheEmpty = $false
            if ($result.State.Mode -eq 'Offline') {
                $cacheEmpty = -not (Test-DirectoryHasEntries $result.LocalDesktop)
            }
            $logs.Add((Format-DesktopSwitchMessage -Switched $result.Switched -Mode $result.State.Mode -DesiredDesktop $result.DesiredDesktop -ProbeStatus $probeStatus -RestartedExplorer $explorer.Restarted -CacheEmpty $cacheEmpty))
            if ($applied.KnownFolderHResult -ne 0) {
                $code = '{0:X8}' -f [uint32]$applied.KnownFolderHResult
                $logs.Add("Системный вызов смены папки вернул код 0x$code. Значение записано в реестр пользователя.")
            }
            if (-not [string]::IsNullOrWhiteSpace($applied.NativeError)) {
                $logs.Add("Системный вызов смены папки недоступен: $($applied.NativeError). Значение записано в реестр пользователя.")
            }
            $registered = Get-RegisteredDesktopPath
            if (-not (Compare-DesktopPath $registered $result.DesiredDesktop)) {
                $logs.Add('Реестр по-прежнему содержит другой путь. Если его возвращает групповая политика, программа запишет путь снова на следующем цикле.')
            }
        }
    }

    return [pscustomobject]@{ Result = $result; Logs = $logs }
}

if (-not (Test-IsWindowsPlatform)) {
    Write-Output 'DesktopFailover работает только в Windows.'
    exit 1
}

try { Set-Location -LiteralPath ([System.IO.Path]::GetTempPath()) } catch {}

$locations = Resolve-MonitorLocations -ConfigPath $ConfigPath -StatePath $StatePath -LogPath $LogPath

if ($Status) {
    Show-FailoverStatus -Locations $locations
}
if ($Preview) {
    Show-FailoverPreview -Locations $locations
}

$mutex = $null
$owned = $false
try {
    $mutex = New-Object System.Threading.Mutex($false, 'Local\DesktopFailover.SingleInstance')
    try {
        $owned = $mutex.WaitOne(0, $false)
    } catch [System.Threading.AbandonedMutexException] {
        $owned = $true
    }
    if (-not $owned) {
        Write-FailoverLog 'Копия уже работает, этот запуск завершён.' $locations.LogPath
        exit 0
    }

    $state = Read-FailoverState $locations.StatePath
    Write-FailoverLog "DesktopFailover $(Get-DesktopFailoverVersion) запущен. Конфиг: $($locations.ConfigPath)" $locations.LogPath
    $script:LastRepeatLog = ''
    $config = $null

    while ($true) {
        try {
            $config = Import-FailoverConfig $locations.ConfigPath
            $cycle = Invoke-MonitorCycle -Config $config -State $state
            $state = $cycle.Result.State
            Write-FailoverState -State $state -Path $locations.StatePath
            foreach ($line in @($cycle.Logs)) {
                if ([string]::IsNullOrWhiteSpace($line)) { continue }
                if (-not $cycle.Result.Ok) {
                    if ($line -eq $script:LastRepeatLog) { continue }
                    $script:LastRepeatLog = $line
                } else {
                    $script:LastRepeatLog = ''
                }
                Write-FailoverLog $line $locations.LogPath
            }
            if ($cycle.Result.Ok) { $script:LastRepeatLog = '' }
        } catch {
            $message = "Ошибка цикла: $($_.Exception.Message)"
            if ($message -ne $script:LastRepeatLog) {
                Write-FailoverLog $message $locations.LogPath
                $script:LastRepeatLog = $message
            }
        }
        if ($Once) { break }
        $seconds = 15
        if ($null -ne $config) { $seconds = [int]$config.PollSeconds }
        Start-Sleep -Seconds $seconds
    }
} finally {
    if ($owned -and $null -ne $mutex) {
        try { [void]$mutex.ReleaseMutex() } catch {}
        $mutex.Dispose()
    }
}
