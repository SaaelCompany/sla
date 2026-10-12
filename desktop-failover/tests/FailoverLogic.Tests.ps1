#Requires -Version 5.0

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'FailoverLogic.ps1')
. (Join-Path $root 'NetworkProbe.ps1')

$script:Pass = 0
$script:Fail = 0

function Assert-True {
    param([string]$Name, [bool]$Condition)
    if ($Condition) {
        $script:Pass++
        Write-Host "ok   $Name"
    } else {
        $script:Fail++
        Write-Host "FAIL $Name"
    }
}

function Assert-Equal {
    param([string]$Name, $Actual, $Expected)
    $same = $false
    if ($null -eq $Expected) {
        $same = $null -eq $Actual
    } elseif ($null -eq $Actual) {
        $same = $false
    } else {
        $same = [bool]($Actual -eq $Expected)
    }
    if ($same) {
        $script:Pass++
        Write-Host "ok   $Name"
    } else {
        $script:Fail++
        Write-Host "FAIL $Name"
        Write-Host "     expected: [$Expected]"
        Write-Host "     actual:   [$Actual]"
    }
}

function Assert-Throws {
    param([string]$Name, [scriptblock]$Block)
    $threw = $false
    try { & $Block } catch { $threw = $true }
    Assert-True $Name $threw
}

function New-RawConfig {
    param([hashtable]$Values)
    $obj = New-Object PSObject
    foreach ($key in $Values.Keys) {
        $obj | Add-Member -NotePropertyName $key -NotePropertyValue $Values[$key]
    }
    return $obj
}

function New-TestConfig {
    param([hashtable]$Values)
    if ($null -eq $Values) { $Values = @{} }
    return ConvertTo-FailoverConfig (New-RawConfig $Values)
}

function New-State {
    param(
        [string]$Mode = 'Online',
        [string]$Network = '\\fileserver\shared\Desktop',
        [int]$Failures = 0,
        [int]$Successes = 0,
        $LastSyncUtc = $null
    )
    $state = Get-EmptyFailoverState
    $state.Mode = $Mode
    $state.NetworkDesktop = $Network
    $state.ConsecutiveFailures = $Failures
    $state.ConsecutiveSuccesses = $Successes
    $state.LastSyncUtc = $LastSyncUtc
    return $state
}

Assert-Equal 'version' (Get-DesktopFailoverVersion) '1.1.0'
Assert-True 'unc path' (Test-IsUncPath '\\fileserver\shared\Desktop')
Assert-True 'local path is not unc' (-not (Test-IsUncPath 'C:\Users\a\Desktop'))
Assert-True 'blank path is not unc' (-not (Test-IsUncPath '   '))
Assert-Equal 'unc server' (Get-UncServer '\\fileserver.corp\shared\Desktop') 'fileserver.corp'
Assert-Equal 'unc ip server' (Get-UncServer '\\10.0.0.5\desktop') '10.0.0.5'
Assert-Equal 'local has no server' (Get-UncServer 'C:\Desktop') $null

Assert-Equal 'configured wins' (Resolve-NetworkDesktop '\\other\desk' '\\fileserver\shared\Desktop' '\\fileserver\shared\Desktop') '\\other\desk'
Assert-Equal 'remembered wins over local registry' (Resolve-NetworkDesktop '' '\\fileserver\shared\Desktop' 'C:\Users\a\AppData\Local\OfflineDesktop') '\\fileserver\shared\Desktop'
Assert-Equal 'registry unc' (Resolve-NetworkDesktop '' '' '\\fileserver\shared\Desktop') '\\fileserver\shared\Desktop'
Assert-Equal 'local registry ignored' (Resolve-NetworkDesktop '  ' '' 'C:\Users\a\Desktop') $null

$env:LOCALAPPDATA = (Join-Path ([System.IO.Path]::GetTempPath()) 'desktop-failover-profile')
$resolvedLocal = Resolve-LocalDesktop '%LOCALAPPDATA%\OfflineDesktop'
Assert-True 'local expands' ($resolvedLocal.EndsWith('OfflineDesktop'))
Assert-Throws 'local unc rejected' { Resolve-LocalDesktop '\\server\desktop' }

Assert-True 'share down is offline' (Get-ShouldBeOffline 'share' $false $true)
Assert-True 'share up stays online' (-not (Get-ShouldBeOffline 'share' $true $false))
Assert-True 'internet down is offline in internet mode' (Get-ShouldBeOffline 'internet' $true $false)
Assert-True 'internet up stays online in internet mode' (-not (Get-ShouldBeOffline 'internet' $false $true))
Assert-True 'either failure in shareOrInternet' (Get-ShouldBeOffline 'shareOrInternet' $true $false)
Assert-True 'both up in shareOrInternet' (-not (Get-ShouldBeOffline 'shareOrInternet' $true $true))
Assert-True 'one side up in shareAndInternet' (-not (Get-ShouldBeOffline 'shareAndInternet' $true $false))
Assert-True 'both down in shareAndInternet' (Get-ShouldBeOffline 'shareAndInternet' $false $false)

$counter = Update-FailoverCounter -ShouldBeOffline $true -CurrentMode 'Online' -ConsecutiveFailures 0 -ConsecutiveSuccesses 0 -FailureThreshold 2 -RecoveryThreshold 2
Assert-Equal 'first failure stays online' $counter.Mode 'Online'
Assert-Equal 'first failure count' $counter.ConsecutiveFailures 1
Assert-True 'first failure does not switch' (-not $counter.Switched)
$counter = Update-FailoverCounter -ShouldBeOffline $true -CurrentMode $counter.Mode -ConsecutiveFailures $counter.ConsecutiveFailures -ConsecutiveSuccesses $counter.ConsecutiveSuccesses -FailureThreshold 2 -RecoveryThreshold 2
Assert-Equal 'second failure goes offline' $counter.Mode 'Offline'
Assert-True 'second failure switches' $counter.Switched
Assert-Equal 'failure counter resets' $counter.ConsecutiveFailures 0

$counter = Update-FailoverCounter -ShouldBeOffline $false -CurrentMode 'Offline' -ConsecutiveFailures 0 -ConsecutiveSuccesses 0 -FailureThreshold 2 -RecoveryThreshold 2
Assert-Equal 'first recovery stays offline' $counter.Mode 'Offline'
$counter = Update-FailoverCounter -ShouldBeOffline $false -CurrentMode $counter.Mode -ConsecutiveFailures $counter.ConsecutiveFailures -ConsecutiveSuccesses $counter.ConsecutiveSuccesses -FailureThreshold 2 -RecoveryThreshold 2
Assert-Equal 'second recovery goes online' $counter.Mode 'Online'
Assert-True 'second recovery switches' $counter.Switched

$mode = 'Online'
$failures = 0
$successes = 0
foreach ($offline in @($true, $false, $true, $false)) {
    $counter = Update-FailoverCounter -ShouldBeOffline $offline -CurrentMode $mode -ConsecutiveFailures $failures -ConsecutiveSuccesses $successes -FailureThreshold 2 -RecoveryThreshold 2
    $mode = $counter.Mode
    $failures = $counter.ConsecutiveFailures
    $successes = $counter.ConsecutiveSuccesses
}
Assert-Equal 'flapping stays online' $mode 'Online'
Assert-True 'flapping does not switch' (-not $counter.Switched)

$now = [datetime]::SpecifyKind([datetime]'2026-10-10T12:00:00', [DateTimeKind]::Utc)
Assert-True 'missing sync is due' (Test-IntervalElapsed $null 60 $now)
Assert-True 'recent sync is not due' (-not (Test-IntervalElapsed $now.AddSeconds(-10).ToString('o') 60 $now))
Assert-True 'old sync is due' (Test-IntervalElapsed $now.AddMinutes(-5).ToString('o') 60 $now)

$pathsEqual = Compare-DesktopPath '\\Server\Share\Desktop\' '\\server\share\Desktop'
Assert-True 'path compare ignores case and slash' $pathsEqual

$config = New-TestConfig @{
    networkDesktop = '\\fileserver\shared\Desktop'
    localDesktop = 'C:\OfflineDesktop'
    probeMode = 'share'
    failureThreshold = 2
    recoveryThreshold = 2
    syncIntervalSeconds = 60
}
$first = Invoke-FailoverCycle -Config $config -State (New-State) -RegistryDesktop '\\fileserver\shared\Desktop' -ShareUp $false -InternetUp $true -UtcNow $now
Assert-True 'one outage keeps ok' $first.Ok
Assert-Equal 'one outage stays online' $first.State.Mode 'Online'
Assert-True 'one outage does not apply' (-not $first.ShouldApply)
Assert-True 'share down does not sync' (-not $first.ShouldSync)

$second = Invoke-FailoverCycle -Config $config -State $first.State -RegistryDesktop '\\fileserver\shared\Desktop' -ShareUp $false -InternetUp $true -UtcNow $now
Assert-Equal 'two outages go offline' $second.State.Mode 'Offline'
Assert-True 'two outages switch' $second.Switched
Assert-True 'two outages apply local path' $second.ShouldApply
Assert-Equal 'desired local path' $second.DesiredDesktop 'C:\OfflineDesktop'
Assert-True 'offline with dead share does not sync' (-not $second.ShouldSync)

$held = Invoke-FailoverCycle -Config $config -State $second.State -RegistryDesktop 'C:\OfflineDesktop' -ShareUp $false -InternetUp $false -UtcNow $now
Assert-True 'stable offline does not reapply' (-not $held.ShouldApply)

$gpo = Invoke-FailoverCycle -Config $config -State $second.State -RegistryDesktop '\\fileserver\shared\Desktop' -ShareUp $false -InternetUp $true -UtcNow $now
Assert-Equal 'gpo revert stays offline' $gpo.State.Mode 'Offline'
Assert-True 'gpo revert reapplies local path' $gpo.ShouldApply
Assert-True 'gpo revert is not a new switch' (-not $gpo.Switched)

$recover1 = Invoke-FailoverCycle -Config $config -State $second.State -RegistryDesktop 'C:\OfflineDesktop' -ShareUp $true -InternetUp $false -UtcNow $now
Assert-Equal 'share mode ignores dead internet' $recover1.State.Mode 'Offline'
Assert-Equal 'recovery count' $recover1.State.ConsecutiveSuccesses 1
$recover2 = Invoke-FailoverCycle -Config $config -State $recover1.State -RegistryDesktop 'C:\OfflineDesktop' -ShareUp $true -InternetUp $false -UtcNow $now
Assert-Equal 'share restored' $recover2.State.Mode 'Online'
Assert-True 'share restored applies unc' $recover2.ShouldApply
Assert-Equal 'desired network path' $recover2.DesiredDesktop '\\fileserver\shared\Desktop'

$internetConfig = New-TestConfig @{
    networkDesktop = '\\fileserver\shared\Desktop'
    localDesktop = 'C:\OfflineDesktop'
    probeMode = 'internet'
    failureThreshold = 1
    internetProbes = @('http://example.test/check')
}
$recent = $now.AddSeconds(-5).ToString('o')
$internetDown = Invoke-FailoverCycle -Config $internetConfig -State (New-State -LastSyncUtc $recent) -RegistryDesktop '\\fileserver\shared\Desktop' -ShareUp $true -InternetUp $false -UtcNow $now
Assert-Equal 'internet mode switches' $internetDown.State.Mode 'Offline'
Assert-True 'fresh copy before offline switch' $internetDown.ShouldSync

$syncDue = Invoke-FailoverCycle -Config $config -State (New-State -LastSyncUtc $null) -RegistryDesktop '\\fileserver\shared\Desktop' -ShareUp $true -InternetUp $true -UtcNow $now
Assert-True 'first sync is due' $syncDue.ShouldSync
Assert-True 'healthy share does not switch' (-not $syncDue.ShouldApply)
$notDue = Invoke-FailoverCycle -Config $config -State (New-State -LastSyncUtc $now.AddSeconds(-10).ToString('o')) -RegistryDesktop '\\fileserver\shared\Desktop' -ShareUp $true -InternetUp $true -UtcNow $now
Assert-True 'recent sync waits' (-not $notDue.ShouldSync)

$missing = Invoke-FailoverCycle -Config (New-TestConfig @{ networkDesktop = ''; localDesktop = 'C:\OfflineDesktop' }) -State (Get-EmptyFailoverState) -RegistryDesktop 'C:\Users\a\Desktop' -ShareUp $false -InternetUp $false -UtcNow $now
Assert-True 'missing network is not ok' (-not $missing.Ok)
Assert-True 'missing network does not apply' (-not $missing.ShouldApply)

$same = Invoke-FailoverCycle -Config (New-TestConfig @{ networkDesktop = 'C:\Same'; localDesktop = 'C:\Same' }) -State (Get-EmptyFailoverState) -RegistryDesktop 'C:\Same' -ShareUp $true -InternetUp $true -UtcNow $now
Assert-True 'same paths rejected' (-not $same.Ok)

Assert-Throws 'bad probe mode' { New-TestConfig @{ probeMode = 'ping'; localDesktop = 'C:\OfflineDesktop' } }
Assert-Throws 'poll too small' { New-TestConfig @{ pollSeconds = 1; localDesktop = 'C:\OfflineDesktop' } }
Assert-Throws 'bad probe url' { New-TestConfig @{ probeMode = 'internet'; internetProbes = @('ftp://files'); localDesktop = 'C:\OfflineDesktop' } }

$examplePath = Join-Path $root 'config.example.json'
$example = ConvertTo-FailoverConfig ([System.IO.File]::ReadAllText($examplePath) | ConvertFrom-Json)
Assert-Equal 'example mode' $example.ProbeMode 'share'
Assert-Equal 'example threshold' $example.FailureThreshold 2
Assert-Equal 'example probes' $example.InternetProbes.Count 2
Assert-True 'example restarts explorer' $example.RestartExplorer
Assert-True 'example does not sync back' (-not $example.SyncBackOnRecovery)

$stateDir = Join-Path ([System.IO.Path]::GetTempPath()) ("desktop-failover-state-" + [guid]::NewGuid().ToString('N'))
[void][System.IO.Directory]::CreateDirectory($stateDir)
try {
    $stateFile = Join-Path $stateDir 'state.json'
    $stored = New-State -Mode 'Offline' -Network '\\fileserver\shared\Desktop' -Failures 0 -Successes 1
    $stored.LastProbeUtc = $now.ToString('o')
    Write-FailoverState -State $stored -Path $stateFile
    $loaded = Read-FailoverState $stateFile
    Assert-Equal 'state mode' $loaded.Mode 'Offline'
    Assert-Equal 'state network' $loaded.NetworkDesktop '\\fileserver\shared\Desktop'
    Assert-Equal 'state successes' $loaded.ConsecutiveSuccesses 1
    Assert-True 'state probe saved' (-not [string]::IsNullOrWhiteSpace($loaded.LastProbeUtc))

    [System.IO.File]::WriteAllText($stateFile, '{bad')
    Assert-Throws 'corrupt state throws' { Read-FailoverState $stateFile }
    Assert-True 'corrupt state is backed up' ([System.IO.File]::Exists("$stateFile.bad"))

    [System.IO.File]::WriteAllText($stateFile, '{"mode":"sideways","networkDesktop":"\\\\fileserver\\shared\\Desktop"}')
    $fixed = Read-FailoverState $stateFile
    Assert-Equal 'bad mode becomes online' $fixed.Mode 'Online'
    Assert-Equal 'network kept' $fixed.NetworkDesktop '\\fileserver\shared\Desktop'
} finally {
    Remove-Item -LiteralPath $stateDir -Recurse -Force
}

$syncRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("desktop-failover-sync-" + [guid]::NewGuid().ToString('N'))
$sourceDir = Join-Path $syncRoot 'source'
$destDir = Join-Path $syncRoot 'dest'
[void][System.IO.Directory]::CreateDirectory($sourceDir)
[void][System.IO.Directory]::CreateDirectory((Join-Path $sourceDir 'folder'))
try {
    $stamp = [datetime]::UtcNow.AddHours(-2)
    $nestedFile = Join-Path (Join-Path $sourceDir 'folder') 'b.txt'
    [System.IO.File]::WriteAllText((Join-Path $sourceDir 'a.lnk'), 'shortcut')
    [System.IO.File]::SetLastWriteTimeUtc((Join-Path $sourceDir 'a.lnk'), $stamp)
    [System.IO.File]::WriteAllText($nestedFile, 'nested')
    [System.IO.File]::WriteAllText((Join-Path $sourceDir 'thumbs.db'), 'nope')
    [System.IO.File]::WriteAllText((Join-Path $sourceDir 'note.tmp'), 'tmp')
    [System.IO.File]::WriteAllText((Join-Path $sourceDir '~$book.xlsx'), 'lock')
    [System.IO.File]::WriteAllText((Join-Path $sourceDir 'state.json'), 'state')
    [System.IO.File]::WriteAllText((Join-Path $sourceDir 'big.bin'), '0123456789abcdef')
    [void][System.IO.Directory]::CreateDirectory($destDir)
    [System.IO.File]::WriteAllText((Join-Path $destDir 'keep.txt'), 'local-only')

    $sync = Sync-TreeOneWay -Source $sourceDir -Destination $destDir -MaxFileBytes 10
    Assert-Equal 'copied shortcut and nested file' $sync.Copied 2
    Assert-True 'nested file arrived' ([System.IO.File]::Exists((Join-Path (Join-Path $destDir 'folder') 'b.txt')))
    Assert-True 'thumbs skipped' (-not [System.IO.File]::Exists((Join-Path $destDir 'thumbs.db')))
    Assert-True 'tmp skipped' (-not [System.IO.File]::Exists((Join-Path $destDir 'note.tmp')))
    Assert-True 'office lock skipped' (-not [System.IO.File]::Exists((Join-Path $destDir '~$book.xlsx')))
    Assert-True 'state skipped' (-not [System.IO.File]::Exists((Join-Path $destDir 'state.json')))
    Assert-True 'big file skipped' (-not [System.IO.File]::Exists((Join-Path $destDir 'big.bin')))
    Assert-Equal 'local extra kept' ([System.IO.File]::ReadAllText((Join-Path $destDir 'keep.txt'))) 'local-only'

    $old = Join-Path $sourceDir 'a.lnk'
    $copy = Join-Path $destDir 'a.lnk'
    [System.IO.File]::WriteAllText($old, 'network-old')
    [System.IO.File]::SetLastWriteTimeUtc($old, [datetime]::UtcNow.AddHours(-3))
    [System.IO.File]::WriteAllText($copy, 'local-edit')
    [System.IO.File]::SetLastWriteTimeUtc($copy, [datetime]::UtcNow.AddHours(-1))
    $kept = Sync-TreeOneWay -Source $sourceDir -Destination $destDir -MaxFileBytes 50MB
    Assert-Equal 'newer local edit kept' ([System.IO.File]::ReadAllText($copy)) 'local-edit'

    [System.IO.File]::WriteAllText($old, 'network-new')
    [System.IO.File]::SetLastWriteTimeUtc($old, [datetime]::UtcNow)
    [System.IO.File]::WriteAllText($copy, 'old')
    [System.IO.File]::SetLastWriteTimeUtc($copy, [datetime]::UtcNow.AddHours(-3))
    $updated = Sync-TreeOneWay -Source $sourceDir -Destination $destDir -MaxFileBytes 50MB
    Assert-Equal 'newer network file copied' ([System.IO.File]::ReadAllText($copy)) 'network-new'
    Assert-True 'second sync copied something' ($updated.Copied -ge 1)

    $sameTime = [datetime]::UtcNow.AddMinutes(-30)
    [System.IO.File]::WriteAllText($old, 'same')
    [System.IO.File]::WriteAllText($copy, 'same')
    [System.IO.File]::SetLastWriteTimeUtc($old, $sameTime)
    [System.IO.File]::SetLastWriteTimeUtc($copy, $sameTime)
    $quiet = Sync-TreeOneWay -Source $sourceDir -Destination $destDir -MaxFileBytes 50MB
    Assert-True 'unchanged file is not copied again' ($quiet.Unchanged -ge 1)

    $inside = Sync-TreeOneWay -Source $sourceDir -Destination (Join-Path $sourceDir 'cache') -MaxFileBytes 50MB
    Assert-True 'nested destination rejected' ($inside.Errors.Count -gt 0)
    Assert-Equal 'nested destination copied nothing' $inside.Copied 0
    Assert-True 'nested copy was not created' (-not [System.IO.File]::Exists((Join-Path (Join-Path $sourceDir 'cache') 'a.lnk')))
} finally {
    Remove-Item -LiteralPath $syncRoot -Recurse -Force
}

$linkRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("desktop-failover-link-" + [guid]::NewGuid().ToString('N'))
$linkSource = Join-Path $linkRoot 'source'
$linkDest = Join-Path $linkRoot 'dest'
[void][System.IO.Directory]::CreateDirectory($linkSource)
try {
    [System.IO.File]::WriteAllText((Join-Path $linkSource 'a.txt'), 'file')
    $linked = $true
    try {
        New-Item -ItemType SymbolicLink -Path (Join-Path $linkSource 'loop') -Target $linkSource | Out-Null
        New-Item -ItemType SymbolicLink -Path (Join-Path $linkSource 'link.txt') -Target (Join-Path $linkSource 'a.txt') | Out-Null
    } catch {
        $linked = $false
        Write-Host "skip symlink: $($_.Exception.Message)"
    }
    if ($linked) {
        $linkSync = Sync-TreeOneWay -Source $linkSource -Destination $linkDest -MaxFileBytes 50MB -MaxDepth 5
        Assert-Equal 'reparse points are not followed' $linkSync.Copied 1
        Assert-True 'file symlink is not copied' (-not [System.IO.File]::Exists((Join-Path $linkDest 'link.txt')))
        Assert-True 'directory symlink is not copied' (-not [System.IO.Directory]::Exists((Join-Path $linkDest 'loop')))
    }
} finally {
    Remove-Item -LiteralPath $linkRoot -Recurse -Force
}

$liveDir = Join-Path ([System.IO.Path]::GetTempPath()) ("desktop-failover-live-" + [guid]::NewGuid().ToString('N'))
[void][System.IO.Directory]::CreateDirectory($liveDir)
try {
    Assert-True 'existing directory is reachable' (Test-ShareReachable -Path $liveDir -TimeoutMs 3000)
    $missingDir = Join-Path $liveDir 'missing'
    Assert-True 'missing directory is unreachable' (-not (Test-ShareReachable -Path $missingDir -TimeoutMs 3000))
    Assert-True 'closed smb port is unreachable' (-not (Test-ShareReachable -Path '\\127.0.0.1\no-such-share' -TimeoutMs 1500))
} finally {
    Remove-Item -LiteralPath $liveDir -Recurse -Force
}

Assert-True 'closed http port is offline' (-not (Test-InternetAccess -Urls @('http://127.0.0.1:9/') -TimeoutMs 1500))

$listener = $null
$listenerRunspace = $null
try {
    $listener = New-Object System.Net.HttpListener
    $listener.Prefixes.Add('http://127.0.0.1:18765/')
    $listener.Start()
    $listenerRunspace = [runspacefactory]::CreateRunspace()
    $listenerRunspace.Open()
    $listenerPs = [powershell]::Create()
    $listenerPs.Runspace = $listenerRunspace
    [void]$listenerPs.AddScript({
        param($server)
        $context = $server.GetContext()
        $buffer = [Text.Encoding]::ASCII.GetBytes('OK')
        $context.Response.StatusCode = 200
        $context.Response.OutputStream.Write($buffer, 0, $buffer.Length)
        $context.Response.Close()
    }).AddArgument($listener)
    $handle = $listenerPs.BeginInvoke()
    $online = Test-InternetAccess -Urls @('http://127.0.0.1:18765/health') -TimeoutMs 3000
    Assert-True 'local http probe is online' $online
    if (-not $handle.IsCompleted) { $listenerPs.Stop() }
    $listenerPs.Dispose()
} catch {
    Write-Host "skip http listener: $($_.Exception.Message)"
} finally {
    if ($null -ne $listener -and $listener.IsListening) { $listener.Stop() }
    if ($null -ne $listener) { $listener.Close() }
    if ($null -ne $listenerRunspace) { $listenerRunspace.Dispose() }
}

$message = Format-DesktopSwitchMessage -Switched $true -Mode 'Offline' -DesiredDesktop 'C:\OfflineDesktop' -ProbeStatus 'сетевая папка недоступна' -RestartedExplorer $true -CacheEmpty $true
Assert-True 'switch message names local desktop' ($message.Contains('C:\OfflineDesktop'))
Assert-True 'switch message mentions explorer' ($message.Contains('Проводник'))
$preview = Format-PreviewReport -Result $second -ProbeStatus 'сетевая папка недоступна'
Assert-True 'preview names target' ($preview.Contains('C:\OfflineDesktop'))

foreach ($scriptName in @(
    'FailoverLogic.ps1',
    'NetworkProbe.ps1',
    'DesktopShell.ps1',
    'DesktopFailover.ps1',
    'Install-DesktopFailover.ps1',
    'Uninstall-DesktopFailover.ps1',
    'WidgetLogic.ps1',
    'MonitorLoop.ps1',
    'DesktopWidget.ps1'
)) {
    $scriptPath = Join-Path $root $scriptName
    $tokens = $null
    $parseErrors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$tokens, [ref]$parseErrors)
    $errorCount = 0
    if ($null -ne $parseErrors) { $errorCount = @($parseErrors).Count }
    Assert-Equal "$scriptName parses" $errorCount 0
    if ($errorCount -gt 0) {
        foreach ($parseError in @($parseErrors)) { Write-Host $parseError.ToString() }
    }
}

Write-Host ""
Write-Host ("passed: {0}  failed: {1}" -f $script:Pass, $script:Fail)
if ($script:Fail -gt 0) { exit 1 }
exit 0
