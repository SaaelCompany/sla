#Requires -Version 5.0

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

function Update-WidgetBridgeMode {
    param($Bridge, $State, [string]$ErrorMessage, [int]$OutboxCount)
    if ($null -eq $Bridge) { return }
    $mode = 'Online'
    if ($null -ne $State -and -not [string]::IsNullOrWhiteSpace([string]$State.Mode)) { $mode = [string]$State.Mode }
    $Bridge.Mode = $mode
    $Bridge.OutboxCount = $OutboxCount
    $Bridge.StatusText = Format-WidgetStatus -Mode $mode -ErrorMessage $ErrorMessage -OutboxCount $OutboxCount
}

function Publish-WidgetFeedFromConfig {
    param(
        $WidgetConfig,
        [string]$Mode,
        [string]$DataDirectory,
        $Bridge,
        [string]$LogPath
    )
    if ($null -eq $WidgetConfig -or -not $WidgetConfig.Enabled) { return }
    if ([string]::IsNullOrWhiteSpace($WidgetConfig.FeedUrl)) { return }
    $paths = Get-WidgetStoragePaths $DataDirectory
    $allowNetwork = $true
    if ((Test-IsUncPath $WidgetConfig.FeedUrl) -and $Mode -eq 'Offline') { $allowNetwork = $false }
    $snapshot = Read-WidgetFeedSnapshot -FeedUrl $WidgetConfig.FeedUrl -CachePath $paths.CachePath -AllowNetwork $allowNetwork
    if (-not [string]::IsNullOrWhiteSpace($snapshot.Message)) {
        if ($snapshot.Message -ne $script:LastFeedError) {
            Write-FailoverLog "Лента: $($snapshot.Message)" $LogPath
            $script:LastFeedError = $snapshot.Message
        }
    } else {
        $script:LastFeedError = ''
    }
    $published = Publish-WidgetFeed -Items $snapshot.Items -FromCache $snapshot.FromCache -Message $snapshot.Message -Bridge $Bridge -StatePath $paths.StatePath
    $toastCount = @($published.Toast).Count
    if ($toastCount -gt 0) {
        Write-FailoverLog "Новых сообщений для уведомления: $toastCount." $LogPath
    }
}

function Send-WidgetOutbox {
    param(
        $WidgetConfig,
        [string]$Mode,
        [string]$DataDirectory,
        $Bridge,
        [string]$LogPath
    )
    if ($null -eq $WidgetConfig) { return }
    $paths = Get-WidgetStoragePaths $DataDirectory
    $pending = Read-OutboxTickets $paths.OutboxPath
    if ($null -ne $Bridge) { $Bridge.OutboxCount = $pending.Count }
    if ($pending.Count -eq 0) { return }
    if ($Mode -ne 'Online') { return }
    if ([string]::IsNullOrWhiteSpace($WidgetConfig.ApiBaseUrl)) { return }
    $apiBaseUrl = $WidgetConfig.ApiBaseUrl
    $serviceDeskId = $WidgetConfig.ServiceDeskId
    $requestTypeId = $WidgetConfig.RequestTypeId
    $sender = {
        param($Ticket)
        Invoke-ServiceDeskRequest `
            -ApiBaseUrl $apiBaseUrl `
            -ServiceDeskId $serviceDeskId `
            -RequestTypeId $requestTypeId `
            -Summary $Ticket.Summary `
            -Description $Ticket.Description
    }.GetNewClosure()
    $result = Send-OutboxTickets -Path $paths.OutboxPath -Send $sender
    foreach ($key in @($result.Sent)) {
        if (-not [string]::IsNullOrWhiteSpace([string]$key)) {
            Write-FailoverLog "Заявка отправлена: $key" $LogPath
        }
    }
    if ($null -ne $Bridge) { $Bridge.OutboxCount = [int]$result.Pending }
}

function Get-WidgetStoragePaths {
    param([string]$DataDirectory)
    [pscustomobject]@{
        StatePath = Join-Path $DataDirectory 'widget-state.json'
        CachePath = Join-Path $DataDirectory 'news-cache.json'
        OutboxPath = Join-Path $DataDirectory 'outbox.json'
    }
}

function Start-FailoverMonitorLoop {
    param(
        [string]$ConfigPath,
        [string]$StatePath,
        [string]$LogPath,
        $Bridge,
        [switch]$Once
    )
    $state = Read-FailoverState $StatePath
    Write-FailoverLog "DesktopFailover $(Get-DesktopFailoverVersion) запущен. Конфиг: $ConfigPath" $LogPath
    $script:LastRepeatLog = ''
    $script:LastFeedError = ''
    $config = $null
    $nextFeed = [datetime]::MinValue
    $nextOutbox = [datetime]::MinValue
    $dataDirectory = [System.IO.Path]::GetDirectoryName($StatePath)

    while ($true) {
        if ($null -ne $Bridge -and $Bridge.ExitRequested) { break }
        $widget = $null
        try {
            $config = Import-FailoverConfig $ConfigPath
            try { $widget = Import-WidgetConfig $ConfigPath } catch {
                $widgetError = "Настройки виджета: $($_.Exception.Message)"
                if ($widgetError -ne $script:LastRepeatLog) {
                    Write-FailoverLog $widgetError $LogPath
                    $script:LastRepeatLog = $widgetError
                }
            }
            $cycle = Invoke-MonitorCycle -Config $config -State $state
            $state = $cycle.Result.State
            Write-FailoverState -State $state -Path $StatePath
            foreach ($line in @($cycle.Logs)) {
                if ([string]::IsNullOrWhiteSpace($line)) { continue }
                if (-not $cycle.Result.Ok) {
                    if ($line -eq $script:LastRepeatLog) { continue }
                    $script:LastRepeatLog = $line
                } else {
                    $script:LastRepeatLog = ''
                }
                Write-FailoverLog $line $LogPath
            }
            if ($cycle.Result.Ok) { $script:LastRepeatLog = '' }
            $outboxCount = 0
            if ($null -ne $widget) {
                $paths = Get-WidgetStoragePaths $dataDirectory
                $outboxCount = (Read-OutboxTickets $paths.OutboxPath).Count
            }
            $statusError = ''
            if (-not $cycle.Result.Ok) { $statusError = [string]$cycle.Result.Message }
            Update-WidgetBridgeMode -Bridge $Bridge -State $state -ErrorMessage $statusError -OutboxCount $outboxCount

            $now = Get-Date
            if ($null -ne $widget -and $widget.Enabled -and $now -ge $nextFeed) {
                Publish-WidgetFeedFromConfig -WidgetConfig $widget -Mode $state.Mode -DataDirectory $dataDirectory -Bridge $Bridge -LogPath $LogPath
                $nextFeed = $now.AddSeconds([int]$widget.FeedPollSeconds)
            }
            $sendOutbox = $now -ge $nextOutbox
            if ($null -ne $Bridge -and $Bridge.OutboxDirty) { $sendOutbox = $true }
            if ($sendOutbox -and $null -ne $widget) {
                Send-WidgetOutbox -WidgetConfig $widget -Mode $state.Mode -DataDirectory $dataDirectory -Bridge $Bridge -LogPath $LogPath
                if ($null -ne $Bridge) {
                    $Bridge.OutboxDirty = $false
                    Update-WidgetBridgeMode -Bridge $Bridge -State $state -ErrorMessage $statusError -OutboxCount ([int]$Bridge.OutboxCount)
                }
                $nextOutbox = $now.AddSeconds(60)
            }
        } catch {
            $message = "Ошибка цикла: $($_.Exception.Message)"
            if ($message -ne $script:LastRepeatLog) {
                Write-FailoverLog $message $LogPath
                $script:LastRepeatLog = $message
            }
            Update-WidgetBridgeMode -Bridge $Bridge -State $state -ErrorMessage $message -OutboxCount 0
        }
        if ($Once) { break }
        if ($null -ne $Bridge -and $Bridge.ExitRequested) { break }
        $seconds = 15
        if ($null -ne $config) { $seconds = [int]$config.PollSeconds }
        Start-Sleep -Seconds $seconds
    }
}
