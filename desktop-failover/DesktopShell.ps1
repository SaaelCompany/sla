#Requires -Version 5.0

$script:DesktopFailoverNativeCSharp = @'
using System;
using System.Runtime.InteropServices;

namespace DesktopFailover
{
    public static class Native
    {
        public static readonly Guid DesktopFolderId = new Guid("B4BFCC3A-DB2C-424C-B029-7FE99A87C641");

        [DllImport("shell32.dll")]
        public static extern void SHChangeNotify(int wEventId, uint uFlags, IntPtr dwItem1, IntPtr dwItem2);

        [DllImport("shell32.dll", CharSet = CharSet.Unicode)]
        public static extern int SHSetKnownFolderPath(ref Guid rfid, uint dwFlags, IntPtr hToken, string pszPath);

        [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
        public static extern IntPtr SendMessageTimeout(
            IntPtr hWnd,
            uint Msg,
            UIntPtr wParam,
            string lParam,
            uint fuFlags,
            uint uTimeout,
            out UIntPtr lpdwResult);

        [DllImport("kernel32.dll", CharSet = CharSet.Unicode)]
        public static extern uint GetDriveType(string lpRootPathName);
    }
}
'@

function Initialize-DesktopNative {
    if ('DesktopFailover.Native' -as [type]) { return }
    Add-Type -TypeDefinition $script:DesktopFailoverNativeCSharp -Language CSharp -ErrorAction Stop
}

function Get-RegisteredDesktopPath {
    if (-not (Test-IsWindowsPlatform)) { return '' }
    $key = $null
    try {
        $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey(
            'Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders')
        if ($null -eq $key) { return '' }
        $value = $key.GetValue(
            'Desktop',
            '',
            [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
        if ($null -eq $value) { return '' }
        return [string]$value
    } catch {
        return ''
    } finally {
        if ($null -ne $key) { $key.Dispose() }
    }
}

function Set-DesktopLocation {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-IsWindowsPlatform)) {
        throw 'Смена рабочего стола работает только в Windows.'
    }
    [void][System.IO.Directory]::CreateDirectory($Path)

    $knownFolderHResult = 0
    $nativeError = $null
    try {
        Initialize-DesktopNative
        $guid = [DesktopFailover.Native]::DesktopFolderId
        $knownFolderHResult = [DesktopFailover.Native]::SHSetKnownFolderPath([ref]$guid, 0, [IntPtr]::Zero, $Path)
    } catch {
        $nativeError = $_.Exception.Message
    }

    # Реестр записывается после системного вызова и остаётся итоговым значением,
    # даже если политика запретила SHSetKnownFolderPath.
    $userKey = $null
    $shellKey = $null
    try {
        $userKey = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey(
            'Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders')
        $userKey.SetValue('Desktop', $Path, [Microsoft.Win32.RegistryValueKind]::ExpandString)
        $userKey.Flush()
        $shellKey = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey(
            'Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders')
        $shellKey.SetValue('Desktop', $Path, [Microsoft.Win32.RegistryValueKind]::String)
        $shellKey.Flush()
    } finally {
        if ($null -ne $userKey) { $userKey.Dispose() }
        if ($null -ne $shellKey) { $shellKey.Dispose() }
    }

    [pscustomobject]@{
        Path = $Path
        KnownFolderHResult = [int]$knownFolderHResult
        NativeError = $nativeError
    }
}

function Test-IsRemoteDrive {
    param([string]$Path)
    if (Test-IsUncPath $Path) { return $true }
    if (-not (Test-IsWindowsPlatform)) { return $false }
    $root = [System.IO.Path]::GetPathRoot($Path)
    if ([string]::IsNullOrWhiteSpace($root)) { return $false }
    try {
        Initialize-DesktopNative
        $kind = [DesktopFailover.Native]::GetDriveType($root)
        if ($kind -eq 4) { return $true }
        return $false
    } catch {
        return $false
    }
}

function Restart-ExplorerShell {
    if (-not (Test-IsWindowsPlatform)) { return }
    $existing = @(Get-Process -Name 'explorer' -ErrorAction SilentlyContinue)
    if ($existing.Count -eq 0) { return }
    foreach ($proc in $existing) {
        try { Stop-Process -Id $proc.Id -Force -ErrorAction Stop } catch {}
    }
    Start-Sleep -Milliseconds 800
    $still = @(Get-Process -Name 'explorer' -ErrorAction SilentlyContinue)
    if ($still.Count -eq 0) {
        Start-Process -FilePath (Join-Path $env:WINDIR 'explorer.exe') | Out-Null
    }
}

function Update-ExplorerDesktop {
    param([bool]$RestartExplorer)
    $nativeOk = $true
    try {
        Initialize-DesktopNative
        [DesktopFailover.Native]::SHChangeNotify(0x08000000, 0x1000, [IntPtr]::Zero, [IntPtr]::Zero)
        $unused = [UIntPtr]::Zero
        [void][DesktopFailover.Native]::SendMessageTimeout(
            [IntPtr]0xffff,
            0x001A,
            [UIntPtr]::Zero,
            'Shell',
            0x0002,
            2000,
            [ref]$unused)
    } catch {
        $nativeOk = $false
    }
    $restarted = $false
    if ($RestartExplorer) {
        Restart-ExplorerShell
        $restarted = $true
    }
    [pscustomobject]@{
        NativeOk = $nativeOk
        Restarted = $restarted
    }
}

function Stop-DesktopFailoverProcess {
    param([int]$ExceptPid = $PID)
    if (-not (Test-IsWindowsPlatform)) { return 0 }
    $stopped = 0
    foreach ($name in @('powershell.exe', 'pwsh.exe')) {
        $processes = @(Get-CimInstance Win32_Process -Filter "Name = '$name'" -ErrorAction SilentlyContinue)
        foreach ($proc in $processes) {
            if ([int]$proc.ProcessId -eq $ExceptPid) { continue }
            $commandLine = [string]$proc.CommandLine
            if ($commandLine -like '*DesktopFailover.ps1*') {
                try {
                    Stop-Process -Id ([int]$proc.ProcessId) -Force -ErrorAction Stop
                    $stopped++
                } catch {}
            }
        }
    }
    return $stopped
}
