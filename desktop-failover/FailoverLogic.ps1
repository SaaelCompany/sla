#Requires -Version 5.0

function Get-DesktopFailoverVersion {
    return '1.0.0'
}

function Test-IsWindowsPlatform {
    if ($PSVersionTable.PSVersion.Major -ge 6) {
        return [bool]$IsWindows
    }
    return $env:OS -eq 'Windows_NT'
}

function Get-Prop {
    param($Obj, [string]$Name, $Default)
    if ($null -eq $Obj) { return $Default }
    foreach ($property in $Obj.PSObject.Properties) {
        if ($property.Name -eq $Name) {
            if ($null -eq $property.Value) { return $Default }
            return $property.Value
        }
    }
    return $Default
}

function ConvertTo-StringArray {
    param($Value)
    $items = New-Object System.Collections.Generic.List[string]
    foreach ($item in @($Value)) {
        if ($null -eq $item) { continue }
        $text = ([string]$item).Trim()
        if (-not [string]::IsNullOrWhiteSpace($text)) {
            $items.Add($text)
        }
    }
    return ,$items.ToArray()
}

function ConvertTo-NonNegativeInt {
    param($Value, [int]$Default)
    try {
        if ($null -eq $Value) { return $Default }
        if ([string]::IsNullOrWhiteSpace([string]$Value)) { return $Default }
        $number = [int]$Value
        if ($number -lt 0) { return $Default }
        return $number
    } catch {
        return $Default
    }
}

function ConvertTo-BoundedInt {
    param($Value, [int64]$Default, [int64]$Min, [int64]$Max, [string]$Name)
    $number = $Default
    if ($null -ne $Value -and -not [string]::IsNullOrWhiteSpace([string]$Value)) {
        try {
            $number = [int64]$Value
        } catch {
            throw "Поле $Name должно быть целым числом."
        }
    }
    if ($number -lt $Min -or $number -gt $Max) {
        throw "Поле $Name должно быть от $Min до $Max."
    }
    return $number
}

function ConvertTo-BoolValue {
    param($Value, [bool]$Default)
    if ($null -eq $Value) { return $Default }
    if ($Value -is [bool]) { return [bool]$Value }
    $text = ([string]$Value).Trim()
    if ($text -eq 'true') { return $true }
    if ($text -eq 'false') { return $false }
    return $Default
}

function ConvertTo-ProbeMode {
    param($Value, [string]$Default)
    $text = $Default
    if ($null -ne $Value -and -not [string]::IsNullOrWhiteSpace([string]$Value)) {
        $text = [string]$Value
    }
    switch ($text.Trim().ToLowerInvariant()) {
        'share' { return 'share' }
        'internet' { return 'internet' }
        'shareorinternet' { return 'shareOrInternet' }
        'shareandinternet' { return 'shareAndInternet' }
        default {
            throw "Неизвестный probeMode: $text. Допустимо: share, internet, shareOrInternet, shareAndInternet."
        }
    }
}

function ConvertTo-UtcTimestamp {
    param($Value)
    if ($null -eq $Value) { return $null }
    if ($Value -is [datetime]) {
        return $Value.ToUniversalTime().ToString('o')
    }
    $text = [string]$Value
    if ([string]::IsNullOrWhiteSpace($text)) { return $null }
    return $text
}

function Get-DefaultFailoverConfig {
    [pscustomobject]@{
        NetworkDesktop = ''
        LocalDesktop = '%LOCALAPPDATA%\OfflineDesktop'
        PollSeconds = 15
        FailureThreshold = 2
        RecoveryThreshold = 2
        ProbeMode = 'share'
        ProbeTimeoutMs = 3000
        SyncIntervalSeconds = 60
        MaxFileBytes = 52428800
        RestartExplorer = $true
        ExplorerRestartCooldownSeconds = 120
        SyncBackOnRecovery = $false
        InternetProbes = @(
            'http://www.msftconnecttest.com/connecttest.txt',
            'http://connectivitycheck.gstatic.com/generate_204'
        )
    }
}

function ConvertTo-FailoverConfig {
    param($Raw)
    if ($null -eq $Raw) { return Get-DefaultFailoverConfig }
    $defaults = Get-DefaultFailoverConfig
    $probeMode = ConvertTo-ProbeMode (Get-Prop $Raw 'probeMode' $defaults.ProbeMode) $defaults.ProbeMode
    $probeValue = Get-Prop $Raw 'internetProbes' $null
    if ($null -eq $probeValue) {
        $probes = ConvertTo-StringArray $defaults.InternetProbes
    } else {
        $probes = ConvertTo-StringArray $probeValue
    }
    if ($probeMode -ne 'share' -and $probes.Count -eq 0) {
        throw 'Для выбранного probeMode нужен хотя бы один адрес в internetProbes.'
    }
    foreach ($probe in $probes) {
        if ($probe -notmatch '^https?://') {
            throw "Адрес проверки интернета должен начинаться с http:// или https://: $probe"
        }
    }
    $localDesktop = ([string](Get-Prop $Raw 'localDesktop' $defaults.LocalDesktop)).Trim()
    if ([string]::IsNullOrWhiteSpace($localDesktop)) {
        throw 'Поле localDesktop не заполнено.'
    }
    [pscustomobject]@{
        NetworkDesktop = ([string](Get-Prop $Raw 'networkDesktop' $defaults.NetworkDesktop)).Trim()
        LocalDesktop = $localDesktop
        PollSeconds = ConvertTo-BoundedInt (Get-Prop $Raw 'pollSeconds' $defaults.PollSeconds) $defaults.PollSeconds 5 3600 'pollSeconds'
        FailureThreshold = ConvertTo-BoundedInt (Get-Prop $Raw 'failureThreshold' $defaults.FailureThreshold) $defaults.FailureThreshold 1 20 'failureThreshold'
        RecoveryThreshold = ConvertTo-BoundedInt (Get-Prop $Raw 'recoveryThreshold' $defaults.RecoveryThreshold) $defaults.RecoveryThreshold 1 20 'recoveryThreshold'
        ProbeMode = $probeMode
        ProbeTimeoutMs = ConvertTo-BoundedInt (Get-Prop $Raw 'probeTimeoutMs' $defaults.ProbeTimeoutMs) $defaults.ProbeTimeoutMs 500 30000 'probeTimeoutMs'
        SyncIntervalSeconds = ConvertTo-BoundedInt (Get-Prop $Raw 'syncIntervalSeconds' $defaults.SyncIntervalSeconds) $defaults.SyncIntervalSeconds 5 86400 'syncIntervalSeconds'
        MaxFileBytes = ConvertTo-BoundedInt (Get-Prop $Raw 'maxFileBytes' $defaults.MaxFileBytes) $defaults.MaxFileBytes 1 10737418240 'maxFileBytes'
        RestartExplorer = ConvertTo-BoolValue (Get-Prop $Raw 'restartExplorer' $defaults.RestartExplorer) $defaults.RestartExplorer
        ExplorerRestartCooldownSeconds = ConvertTo-BoundedInt (Get-Prop $Raw 'explorerRestartCooldownSeconds' $defaults.ExplorerRestartCooldownSeconds) $defaults.ExplorerRestartCooldownSeconds 0 3600 'explorerRestartCooldownSeconds'
        SyncBackOnRecovery = ConvertTo-BoolValue (Get-Prop $Raw 'syncBackOnRecovery' $defaults.SyncBackOnRecovery) $false
        InternetProbes = $probes
    }
}

function Import-FailoverConfig {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path) -or -not [System.IO.File]::Exists($Path)) {
        return Get-DefaultFailoverConfig
    }
    $raw = [System.IO.File]::ReadAllText($Path) | ConvertFrom-Json
    return ConvertTo-FailoverConfig $raw
}

function Get-EmptyFailoverState {
    [pscustomobject]@{
        NetworkDesktop = ''
        Mode = 'Online'
        ConsecutiveFailures = 0
        ConsecutiveSuccesses = 0
        LastSyncUtc = $null
        LastExplorerRestartUtc = $null
        LastProbeUtc = $null
    }
}

function Copy-FailoverState {
    param($State, [string]$LastProbeUtc)
    if ($null -eq $State) { $State = Get-EmptyFailoverState }
    $mode = [string]$State.Mode
    if ($mode -ne 'Online' -and $mode -ne 'Offline') { $mode = 'Online' }
    [pscustomobject]@{
        NetworkDesktop = [string]$State.NetworkDesktop
        Mode = $mode
        ConsecutiveFailures = ConvertTo-NonNegativeInt $State.ConsecutiveFailures 0
        ConsecutiveSuccesses = ConvertTo-NonNegativeInt $State.ConsecutiveSuccesses 0
        LastSyncUtc = ConvertTo-UtcTimestamp $State.LastSyncUtc
        LastExplorerRestartUtc = ConvertTo-UtcTimestamp $State.LastExplorerRestartUtc
        LastProbeUtc = $LastProbeUtc
    }
}

function Read-FailoverState {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path) -or -not [System.IO.File]::Exists($Path)) {
        return Get-EmptyFailoverState
    }
    try {
        $raw = [System.IO.File]::ReadAllText($Path) | ConvertFrom-Json
    } catch {
        $badPath = "$Path.bad"
        [System.IO.File]::Copy($Path, $badPath, $true)
        throw "Файл состояния повреждён и скопирован в $badPath. $($_.Exception.Message)"
    }
    $mode = [string](Get-Prop $raw 'mode' 'Online')
    if ($mode -ne 'Online' -and $mode -ne 'Offline') { $mode = 'Online' }
    [pscustomobject]@{
        NetworkDesktop = [string](Get-Prop $raw 'networkDesktop' '')
        Mode = $mode
        ConsecutiveFailures = ConvertTo-NonNegativeInt (Get-Prop $raw 'consecutiveFailures' 0) 0
        ConsecutiveSuccesses = ConvertTo-NonNegativeInt (Get-Prop $raw 'consecutiveSuccesses' 0) 0
        LastSyncUtc = ConvertTo-UtcTimestamp (Get-Prop $raw 'lastSyncUtc' $null)
        LastExplorerRestartUtc = ConvertTo-UtcTimestamp (Get-Prop $raw 'lastExplorerRestartUtc' $null)
        LastProbeUtc = ConvertTo-UtcTimestamp (Get-Prop $raw 'lastProbeUtc' $null)
    }
}

function Write-FailoverState {
    param($State, [string]$Path)
    $directory = [System.IO.Path]::GetDirectoryName($Path)
    if (-not [string]::IsNullOrWhiteSpace($directory)) {
        [void][System.IO.Directory]::CreateDirectory($directory)
    }
    $payload = [ordered]@{
        networkDesktop = [string]$State.NetworkDesktop
        mode = [string]$State.Mode
        consecutiveFailures = [int]$State.ConsecutiveFailures
        consecutiveSuccesses = [int]$State.ConsecutiveSuccesses
        lastSyncUtc = ConvertTo-UtcTimestamp $State.LastSyncUtc
        lastExplorerRestartUtc = ConvertTo-UtcTimestamp $State.LastExplorerRestartUtc
        lastProbeUtc = ConvertTo-UtcTimestamp $State.LastProbeUtc
    }
    $json = $payload | ConvertTo-Json -Depth 3
    $encoding = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($Path, $json, $encoding)
}

function Test-IsUncPath {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $false }
    $expanded = [Environment]::ExpandEnvironmentVariables($Path.Trim())
    if ($expanded.StartsWith('\\')) { return $true }
    return $false
}

function Get-UncServer {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $null }
    $expanded = [Environment]::ExpandEnvironmentVariables($Path.Trim())
    if ($expanded -match '^\\\\([^\\]+)\\') { return $Matches[1] }
    return $null
}

function Normalize-DesktopPath {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return '' }
    $expanded = [Environment]::ExpandEnvironmentVariables($Path.Trim())
    return $expanded.TrimEnd('\', '/')
}

function Compare-DesktopPath {
    param([string]$Left, [string]$Right)
    $leftPath = Normalize-DesktopPath $Left
    $rightPath = Normalize-DesktopPath $Right
    return $leftPath.Equals($rightPath, [StringComparison]::OrdinalIgnoreCase)
}

function Resolve-NetworkDesktop {
    param(
        [string]$Configured,
        [string]$Remembered,
        [string]$RegistryValue
    )
    if (-not [string]::IsNullOrWhiteSpace($Configured)) {
        return $Configured.Trim()
    }
    foreach ($candidate in @($Remembered, $RegistryValue)) {
        if ([string]::IsNullOrWhiteSpace($candidate)) { continue }
        if (Test-IsUncPath $candidate) { return $candidate.Trim() }
    }
    return $null
}

function Resolve-LocalDesktop {
    param([string]$Configured)
    $value = $Configured
    if ([string]::IsNullOrWhiteSpace($value)) {
        $value = '%LOCALAPPDATA%\OfflineDesktop'
    }
    $expanded = [Environment]::ExpandEnvironmentVariables($value.Trim())
    if (Test-IsUncPath $expanded) {
        throw 'Локальный рабочий стол не может быть сетевым путём. Укажите папку на диске компьютера, например %LOCALAPPDATA%\OfflineDesktop.'
    }
    if ([string]::IsNullOrWhiteSpace($expanded)) {
        throw 'Локальный путь рабочего стола пуст.'
    }
    return $expanded
}

function Get-ShouldBeOffline {
    param(
        [string]$ProbeMode,
        [bool]$ShareUp,
        [bool]$InternetUp
    )
    if ($ProbeMode -eq 'share') {
        $offline = -not $ShareUp
        return [bool]$offline
    }
    if ($ProbeMode -eq 'internet') {
        $offline = -not $InternetUp
        return [bool]$offline
    }
    if ($ProbeMode -eq 'shareOrInternet') {
        $offline = (-not $ShareUp) -or (-not $InternetUp)
        return [bool]$offline
    }
    if ($ProbeMode -eq 'shareAndInternet') {
        $offline = (-not $ShareUp) -and (-not $InternetUp)
        return [bool]$offline
    }
    throw "Неизвестный режим проверки: $ProbeMode"
}

function Update-FailoverCounter {
    param(
        [bool]$ShouldBeOffline,
        [string]$CurrentMode,
        [int]$ConsecutiveFailures,
        [int]$ConsecutiveSuccesses,
        [int]$FailureThreshold = 2,
        [int]$RecoveryThreshold = 2
    )
    if ($FailureThreshold -lt 1) { $FailureThreshold = 1 }
    if ($RecoveryThreshold -lt 1) { $RecoveryThreshold = 1 }
    if ($CurrentMode -ne 'Online' -and $CurrentMode -ne 'Offline') { $CurrentMode = 'Online' }

    $mode = $CurrentMode
    $failures = $ConsecutiveFailures
    $successes = $ConsecutiveSuccesses
    $switched = $false

    if ($ShouldBeOffline) {
        $successes = 0
        if ($mode -eq 'Offline') {
            $failures = 0
        } else {
            $failures++
            if ($failures -ge $FailureThreshold) {
                $mode = 'Offline'
                $switched = $true
                $failures = 0
            }
        }
    } else {
        $failures = 0
        if ($mode -eq 'Online') {
            $successes = 0
        } else {
            $successes++
            if ($successes -ge $RecoveryThreshold) {
                $mode = 'Online'
                $switched = $true
                $successes = 0
            }
        }
    }

    [pscustomobject]@{
        Mode = $mode
        Switched = $switched
        ConsecutiveFailures = $failures
        ConsecutiveSuccesses = $successes
    }
}

function Test-IntervalElapsed {
    param(
        $LastUtc,
        [int]$IntervalSeconds,
        [datetime]$UtcNow = [datetime]::UtcNow
    )
    if ($IntervalSeconds -le 0) { return $true }
    $text = ConvertTo-UtcTimestamp $LastUtc
    if ([string]::IsNullOrWhiteSpace($text)) { return $true }
    try {
        $parsed = [datetime]::Parse(
            $text,
            [Globalization.CultureInfo]::InvariantCulture,
            [Globalization.DateTimeStyles]::RoundtripKind)
    } catch {
        return $true
    }
    $elapsed = ($UtcNow.ToUniversalTime() - $parsed.ToUniversalTime()).TotalSeconds
    if ($elapsed -ge $IntervalSeconds) { return $true }
    return $false
}

function Test-ExcludedDesktopName {
    param([string]$Name)
    if ([string]::IsNullOrWhiteSpace($Name)) { return $true }
    if ($Name -match '^(?i)(thumbs\.db|ehthumbs\.db|state\.json|desktop-failover\.log)$') { return $true }
    if ($Name -like '~$*') { return $true }
    if ($Name -like '*.tmp') { return $true }
    return $false
}

function Test-DirectoryHasEntries {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $false }
    if (-not [System.IO.Directory]::Exists($Path)) { return $false }
    foreach ($entry in [System.IO.Directory]::EnumerateFileSystemEntries($Path)) {
        if ($null -ne $entry) { return $true }
    }
    return $false
}

function Test-PathIsInside {
    param([string]$Parent, [string]$Child)
    $parentFull = [System.IO.Path]::GetFullPath($Parent).TrimEnd('\', '/')
    $childFull = [System.IO.Path]::GetFullPath($Child).TrimEnd('\', '/')
    if ($childFull.Equals($parentFull, [StringComparison]::OrdinalIgnoreCase)) { return $true }
    $prefix = $parentFull + [System.IO.Path]::DirectorySeparatorChar
    if ($childFull.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { return $true }
    return $false
}

function Test-IsReparsePoint {
    param([string]$Path)
    $attributes = [System.IO.File]::GetAttributes($Path)
    if (($attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) { return $true }
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    if ($null -eq $item) { return $false }
    $linkType = $item.PSObject.Properties['LinkType']
    if ($null -ne $linkType -and $linkType.Value -eq 'SymbolicLink') { return $true }
    return $false
}

function Sync-TreeOneWay {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Destination,
        [int64]$MaxFileBytes = 52428800,
        [int]$MaxDepth = 20
    )
    $copied = 0
    $unchanged = 0
    $skipped = 0
    $errors = New-Object System.Collections.Generic.List[string]

    if (-not [System.IO.Directory]::Exists($Source)) {
        $errors.Add("Источник не найден: $Source")
        return [pscustomobject]@{
            Copied = 0
            Unchanged = 0
            Skipped = 0
            Errors = $errors.ToArray()
        }
    }
    if (Test-PathIsInside -Parent $Source -Child $Destination) {
        $errors.Add('Локальная папка не должна лежать внутри сетевой.')
        return [pscustomobject]@{
            Copied = 0
            Unchanged = 0
            Skipped = 0
            Errors = $errors.ToArray()
        }
    }

    [void][System.IO.Directory]::CreateDirectory($Destination)
    $queue = New-Object System.Collections.Generic.Queue[object]
    $queue.Enqueue(@{
        Src = [System.IO.Path]::GetFullPath($Source)
        Dst = [System.IO.Path]::GetFullPath($Destination)
        Depth = 0
    })

    while ($queue.Count -gt 0) {
        $item = $queue.Dequeue()
        if ([int]$item.Depth -gt $MaxDepth) { continue }

        $directories = @()
        try {
            foreach ($directory in [System.IO.Directory]::EnumerateDirectories([string]$item.Src)) {
                $directories += $directory
            }
        } catch {
            $errors.Add($_.Exception.Message)
        }
        foreach ($directory in $directories) {
            $name = [System.IO.Path]::GetFileName($directory)
            if (Test-ExcludedDesktopName $name) { $skipped++; continue }
            try {
                if (Test-IsReparsePoint $directory) { $skipped++; continue }
            } catch {
                $errors.Add($_.Exception.Message)
                continue
            }
            $childDestination = [System.IO.Path]::Combine([string]$item.Dst, $name)
            [void][System.IO.Directory]::CreateDirectory($childDestination)
            $queue.Enqueue(@{
                Src = $directory
                Dst = $childDestination
                Depth = ([int]$item.Depth + 1)
            })
        }

        $files = @()
        try {
            foreach ($file in [System.IO.Directory]::EnumerateFiles([string]$item.Src)) {
                $files += $file
            }
        } catch {
            $errors.Add($_.Exception.Message)
        }
        foreach ($file in $files) {
            $name = [System.IO.Path]::GetFileName($file)
            if (Test-ExcludedDesktopName $name) { $skipped++; continue }
            try {
                if (Test-IsReparsePoint $file) { $skipped++; continue }
                $info = New-Object System.IO.FileInfo $file
                if ($info.Length -gt $MaxFileBytes) { $skipped++; continue }
                $target = [System.IO.Path]::Combine([string]$item.Dst, $name)
                $copy = $true
                if ([System.IO.File]::Exists($target)) {
                    $destinationInfo = New-Object System.IO.FileInfo $target
                    $sourceNewer = $info.LastWriteTimeUtc -gt $destinationInfo.LastWriteTimeUtc.AddSeconds(2)
                    $sizeDiffers = $info.Length -ne $destinationInfo.Length
                    $sourceNotOlder = $info.LastWriteTimeUtc -ge $destinationInfo.LastWriteTimeUtc
                    if ($sourceNewer -or ($sizeDiffers -and $sourceNotOlder)) {
                        $copy = $true
                    } else {
                        $copy = $false
                    }
                }
                if (-not $copy) { $unchanged++; continue }
                if ([System.IO.File]::Exists($target)) {
                    $destinationAttributes = [System.IO.File]::GetAttributes($target)
                    if (($destinationAttributes -band [System.IO.FileAttributes]::ReadOnly) -ne 0) {
                        [System.IO.File]::SetAttributes($target, ($destinationAttributes -bxor [System.IO.FileAttributes]::ReadOnly))
                    }
                }
                [System.IO.File]::Copy($file, $target, $true)
                [System.IO.File]::SetLastWriteTimeUtc($target, $info.LastWriteTimeUtc)
                $kept = $info.Attributes -band ([System.IO.FileAttributes]::Hidden -bor [System.IO.FileAttributes]::System)
                if ($kept -ne 0) {
                    $applied = [System.IO.File]::GetAttributes($target) -bor $kept
                    [System.IO.File]::SetAttributes($target, $applied)
                }
                $copied++
            } catch {
                $errors.Add("${name}: $($_.Exception.Message)")
            }
        }
    }

    [pscustomobject]@{
        Copied = $copied
        Unchanged = $unchanged
        Skipped = $skipped
        Errors = $errors.ToArray()
    }
}

function Format-ProbeStatus {
    param(
        [string]$ProbeMode,
        [bool]$ShareUp,
        [bool]$InternetUp
    )
    $shareText = 'сетевая папка недоступна'
    if ($ShareUp) { $shareText = 'сетевая папка доступна' }
    if ($ProbeMode -eq 'share') { return $shareText }
    $internetText = 'интернет недоступен'
    if ($InternetUp) { $internetText = 'интернет доступен' }
    return "$shareText, $internetText"
}

function Format-DesktopSwitchMessage {
    param(
        [bool]$Switched,
        [string]$Mode,
        [string]$DesiredDesktop,
        [string]$ProbeStatus,
        [bool]$RestartedExplorer,
        [bool]$CacheEmpty
    )
    if ($Switched -and $Mode -eq 'Offline') {
        $text = "Сетевой рабочий стол переключён на локальный: $DesiredDesktop. $ProbeStatus."
    } elseif ($Switched) {
        $text = "Снова включён сетевой рабочий стол: $DesiredDesktop. $ProbeStatus."
    } else {
        $text = "Путь рабочего стола восстановлен: $DesiredDesktop. $ProbeStatus."
    }
    if ($RestartedExplorer) {
        $text += ' Проводник перезапущен, чтобы ярлыки обновились.'
    }
    if ($CacheEmpty -and $Mode -eq 'Offline') {
        $text += ' Локальная копия пока пуста: ярлыки появятся после первой успешной синхронизации.'
    }
    return $text
}

function Format-PreviewReport {
    param($Result, [string]$ProbeStatus)
    if ($null -eq $Result) { return 'Нет результата проверки.' }
    if (-not $Result.Ok) { return [string]$Result.Message }
    $modeText = 'сетевой'
    if ($Result.State.Mode -eq 'Offline') { $modeText = 'локальный' }
    $actionText = 'менять путь не нужно'
    if ($Result.ShouldApply) { $actionText = 'путь будет изменён' }
    $syncText = 'синхронизация не требуется'
    if ($Result.ShouldSync) { $syncText = 'будет обновлена локальная копия' }
    return "Режим после проверки: $modeText. $ProbeStatus. Целевой путь: $($Result.DesiredDesktop). $actionText, $syncText."
}

function Invoke-FailoverCycle {
    param(
        $Config,
        $State,
        [string]$RegistryDesktop,
        [bool]$ShareUp,
        [bool]$InternetUp,
        [datetime]$UtcNow = [datetime]::UtcNow
    )
    $probeStamp = $UtcNow.ToUniversalTime().ToString('o')
    $current = Copy-FailoverState -State $State -LastProbeUtc $probeStamp
    $network = Resolve-NetworkDesktop -Configured $Config.NetworkDesktop -Remembered $current.NetworkDesktop -RegistryValue $RegistryDesktop
    if ([string]::IsNullOrWhiteSpace($network)) {
        return [pscustomobject]@{
            Ok = $false
            Message = 'Сетевой рабочий стол не задан. Укажите networkDesktop в config.json. Если рабочий стол уже перенаправлен, программа берёт UNC-путь из реестра.'
            State = $current
            ShouldApply = $false
            ShouldSync = $false
            ShouldSyncBack = $false
            Switched = $false
            DesiredDesktop = $null
            LocalDesktop = $null
            NetworkDesktop = $null
        }
    }

    $local = Resolve-LocalDesktop -Configured $Config.LocalDesktop
    $expandedNetwork = [Environment]::ExpandEnvironmentVariables($network)
    if (Compare-DesktopPath $local $expandedNetwork) {
        $current.NetworkDesktop = $network
        return [pscustomobject]@{
            Ok = $false
            Message = 'Локальный и сетевой путь рабочего стола совпадают. Укажите отдельную локальную папку в localDesktop.'
            State = $current
            ShouldApply = $false
            ShouldSync = $false
            ShouldSyncBack = $false
            Switched = $false
            DesiredDesktop = $null
            LocalDesktop = $local
            NetworkDesktop = $expandedNetwork
        }
    }

    $offline = Get-ShouldBeOffline -ProbeMode $Config.ProbeMode -ShareUp $ShareUp -InternetUp $InternetUp
    $decision = Update-FailoverCounter `
        -ShouldBeOffline $offline `
        -CurrentMode $current.Mode `
        -ConsecutiveFailures $current.ConsecutiveFailures `
        -ConsecutiveSuccesses $current.ConsecutiveSuccesses `
        -FailureThreshold $Config.FailureThreshold `
        -RecoveryThreshold $Config.RecoveryThreshold

    $desired = $expandedNetwork
    if ($decision.Mode -eq 'Offline') { $desired = $local }

    $shouldSync = $ShareUp -and (Test-IntervalElapsed -LastUtc $current.LastSyncUtc -IntervalSeconds $Config.SyncIntervalSeconds -UtcNow $UtcNow)
    if ($decision.Switched -and $decision.Mode -eq 'Offline' -and $ShareUp) {
        $shouldSync = $true
    }
    $syncBack = $decision.Switched -and $decision.Mode -eq 'Online' -and [bool]$Config.SyncBackOnRecovery -and $ShareUp

    $updated = [pscustomobject]@{
        NetworkDesktop = $network
        Mode = $decision.Mode
        ConsecutiveFailures = $decision.ConsecutiveFailures
        ConsecutiveSuccesses = $decision.ConsecutiveSuccesses
        LastSyncUtc = ConvertTo-UtcTimestamp $current.LastSyncUtc
        LastExplorerRestartUtc = ConvertTo-UtcTimestamp $current.LastExplorerRestartUtc
        LastProbeUtc = $probeStamp
    }

    $apply = -not (Compare-DesktopPath $RegistryDesktop $desired)
    [pscustomobject]@{
        Ok = $true
        Message = $null
        NetworkDesktop = $expandedNetwork
        LocalDesktop = $local
        DesiredDesktop = $desired
        ShouldApply = [bool]$apply
        ShouldSync = [bool]$shouldSync
        ShouldSyncBack = [bool]$syncBack
        Switched = [bool]$decision.Switched
        ShareUp = [bool]$ShareUp
        InternetUp = [bool]$InternetUp
        State = $updated
    }
}
