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
. (Join-Path $PSScriptRoot 'WidgetLogic.ps1')
. (Join-Path $PSScriptRoot 'MonitorLoop.ps1')
. (Join-Path $PSScriptRoot 'DesktopWidget.ps1')

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

function Start-WidgetMonitor {
    param($Locations, $Bridge)
    $runspace = [runspacefactory]::CreateRunspace()
    $runspace.ApartmentState = [System.Threading.ApartmentState]::MTA
    $runspace.Open()
    $worker = [powershell]::Create()
    $worker.Runspace = $runspace
    $root = $PSScriptRoot
    [void]$worker.AddScript({
        param($Root, $ConfigPath, $StatePath, $LogPath, $Bridge)
        Set-Location ([System.IO.Path]::GetTempPath())
        . (Join-Path $Root 'FailoverLogic.ps1')
        . (Join-Path $Root 'NetworkProbe.ps1')
        . (Join-Path $Root 'DesktopShell.ps1')
        . (Join-Path $Root 'WidgetLogic.ps1')
        . (Join-Path $Root 'MonitorLoop.ps1')
        try {
            Start-FailoverMonitorLoop -ConfigPath $ConfigPath -StatePath $StatePath -LogPath $LogPath -Bridge $Bridge
        } catch {
            $Bridge.StatusText = "Ошибка: $($_.Exception.Message)"
        }
    }).AddArgument($root).AddArgument($Locations.ConfigPath).AddArgument($Locations.StatePath).AddArgument($Locations.LogPath).AddArgument($Bridge)
    $handle = $worker.BeginInvoke()
    [pscustomobject]@{
        Worker = $worker
        Runspace = $runspace
        Handle = $handle
    }
}

function New-WidgetBridge {
    [hashtable]::Synchronized(@{
        Mode = 'Online'
        StatusText = 'Проверяю сеть'
        ItemsJson = '{"items":[]}'
        FreshJson = '{"items":[]}'
        FeedGeneration = 0
        UnreadCount = 0
        FromCache = $false
        FeedMessage = ''
        OutboxCount = 0
        OutboxDirty = $false
        ExitRequested = $false
    })
}

if (-not (Test-IsWindowsPlatform)) {
    Write-Output 'DesktopFailover работает только в Windows.'
    exit 1
}

try { Set-Location -LiteralPath ([System.IO.Path]::GetTempPath()) } catch {}

$locations = Resolve-MonitorLocations -ConfigPath $ConfigPath -StatePath $StatePath -LogPath $LogPath

if ($Status) { Show-FailoverStatus -Locations $locations }
if ($Preview) { Show-FailoverPreview -Locations $locations }

$widgetEnabled = $true
try {
    $widgetEnabled = [bool](Import-WidgetConfig $locations.ConfigPath).Enabled
} catch {
    $widgetEnabled = $true
}

if (-not $Once -and $widgetEnabled) {
    $apartment = [System.Threading.Thread]::CurrentThread.GetApartmentState()
    if ($apartment -ne [System.Threading.ApartmentState]::STA) {
        $relaunch = New-Object System.Collections.Generic.List[string]
        [void]$relaunch.Add('-NoProfile')
        [void]$relaunch.Add('-STA')
        [void]$relaunch.Add('-WindowStyle')
        [void]$relaunch.Add('Hidden')
        [void]$relaunch.Add('-ExecutionPolicy')
        [void]$relaunch.Add('Bypass')
        [void]$relaunch.Add('-File')
        [void]$relaunch.Add($PSCommandPath)
        if (-not [string]::IsNullOrWhiteSpace($ConfigPath)) {
            [void]$relaunch.Add('-ConfigPath')
            [void]$relaunch.Add($ConfigPath)
        }
        if (-not [string]::IsNullOrWhiteSpace($StatePath)) {
            [void]$relaunch.Add('-StatePath')
            [void]$relaunch.Add($StatePath)
        }
        if (-not [string]::IsNullOrWhiteSpace($LogPath)) {
            [void]$relaunch.Add('-LogPath')
            [void]$relaunch.Add($LogPath)
        }
        Start-Process -FilePath (Get-CurrentHostExecutable) -ArgumentList $relaunch.ToArray() -WindowStyle Hidden | Out-Null
        exit 0
    }
}

$mutex = $null
$owned = $false
$monitor = $null
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

    if ($Once -or -not $widgetEnabled) {
        Start-FailoverMonitorLoop -ConfigPath $locations.ConfigPath -StatePath $locations.StatePath -LogPath $locations.LogPath -Once:$Once
    } else {
        $bridge = New-WidgetBridge
        $monitor = Start-WidgetMonitor -Locations $locations -Bridge $bridge
        Start-DesktopWidgetHost -Bridge $bridge -ConfigPath $locations.ConfigPath -DataDirectory $locations.DataDirectory
    }
} finally {
    if ($null -ne $monitor) {
        try { $monitor.Worker.Stop() } catch {}
        try { $monitor.Runspace.Close() } catch {}
        try { $monitor.Worker.Dispose() } catch {}
        try { $monitor.Runspace.Dispose() } catch {}
    }
    if ($owned -and $null -ne $mutex) {
        try { [void]$mutex.ReleaseMutex() } catch {}
        $mutex.Dispose()
    }
}
