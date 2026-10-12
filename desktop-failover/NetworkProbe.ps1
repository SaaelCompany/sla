#Requires -Version 5.0

function Get-CurrentHostExecutable {
    $path = ''
    try {
        $path = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
    } catch {
        $path = ''
    }
    if ([string]::IsNullOrWhiteSpace($path)) {
        $path = (Get-Process -Id $PID).Path
    }
    if ([string]::IsNullOrWhiteSpace($path)) {
        throw 'Не удалось определить исполняемый файл PowerShell.'
    }
    return $path
}

function Invoke-BoundedPowerShell {
    param(
        [Parameter(Mandatory)][string]$Command,
        [int]$TimeoutMs
    )
    $bytes = [System.Text.Encoding]::Unicode.GetBytes($Command)
    $encoded = [Convert]::ToBase64String($bytes)
    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = Get-CurrentHostExecutable
    $startInfo.Arguments = "-NoProfile -NonInteractive -EncodedCommand $encoded"
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
    $startInfo.WorkingDirectory = [System.IO.Path]::GetTempPath()
    $process = $null
    try {
        $process = [System.Diagnostics.Process]::Start($startInfo)
        if (-not $process.WaitForExit($TimeoutMs)) {
            try { $process.Kill() } catch {}
            return 124
        }
        return [int]$process.ExitCode
    } finally {
        if ($null -ne $process) { $process.Dispose() }
    }
}

function Test-ShareReachable {
    param(
        [Parameter(Mandatory)][string]$Path,
        [int]$TimeoutMs = 3000
    )
    if ([string]::IsNullOrWhiteSpace($Path)) { return $false }
    if ($TimeoutMs -lt 200) { $TimeoutMs = 200 }

    $server = ''
    if (Test-IsUncPath $Path) {
        $server = [string](Get-UncServer $Path)
        if ([string]::IsNullOrWhiteSpace($server)) { return $false }
    }

    $payload = ConvertTo-Json -InputObject @{
        Path = $Path
        TimeoutMs = $TimeoutMs
        Server = $server
    } -Compress
    $payloadB64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($payload))
    $commandTemplate = @'
$ErrorActionPreference = 'Stop'
$raw = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('PAYLOAD'))
$job = $raw | ConvertFrom-Json
$path = [string]$job.Path
$timeout = [int]$job.TimeoutMs
$server = [string]$job.Server
if (-not [string]::IsNullOrWhiteSpace($server)) {
    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $async = $client.BeginConnect($server, 445, $null, $null)
        if (-not $async.AsyncWaitHandle.WaitOne($timeout, $false)) { exit 3 }
        try { $client.EndConnect($async) } catch { exit 3 }
        if (-not $client.Connected) { exit 3 }
    } catch { exit 3 } finally { $client.Close() }
}
if ([System.IO.Directory]::Exists($path)) { exit 0 }
exit 2
'@
    $command = $commandTemplate.Replace('PAYLOAD', $payloadB64)
    try {
        $code = Invoke-BoundedPowerShell -Command $command -TimeoutMs ($TimeoutMs * 2)
        if ($code -eq 0) { return $true }
        return $false
    } catch {
        return $false
    }
}

function Enable-InternetTls {
    try {
        $current = [System.Net.ServicePointManager]::SecurityProtocol
        $tls12 = [System.Net.SecurityProtocolType]::Tls12
        [System.Net.ServicePointManager]::SecurityProtocol = $current -bor $tls12
    } catch {
        return
    }
}

function Test-OneHttpUrl {
    param(
        [string]$Url,
        [int]$TimeoutMs
    )
    $response = $null
    try {
        $request = [System.Net.HttpWebRequest]::Create($Url)
        $request.Method = 'GET'
        $request.Timeout = $TimeoutMs
        $request.ReadWriteTimeout = $TimeoutMs
        $request.AllowAutoRedirect = $true
        $request.MaximumAutomaticRedirections = 3
        $request.UserAgent = "DesktopFailover/$(Get-DesktopFailoverVersion)"
        $request.UseDefaultCredentials = $true
        $uri = New-Object System.Uri $Url
        $proxy = [System.Net.WebRequest]::GetSystemWebProxy()
        if ($uri.IsLoopback -or $null -eq $proxy -or $proxy.IsBypassed($uri)) {
            $request.Proxy = New-Object System.Net.WebProxy
        } else {
            $request.Proxy = $proxy
            $request.Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
        }
        $response = $request.GetResponse()
        $code = [int]$response.StatusCode
        if ($code -ge 200 -and $code -lt 400) { return $true }
        return $false
    } catch {
        return $false
    } finally {
        if ($null -ne $response) { $response.Close() }
    }
}

function Test-InternetAccess {
    param(
        [string[]]$Urls,
        [int]$TimeoutMs = 3000
    )
    Enable-InternetTls
    if ($null -eq $Urls) { return $false }
    foreach ($url in $Urls) {
        if ([string]::IsNullOrWhiteSpace($url)) { continue }
        if (Test-OneHttpUrl -Url $url -TimeoutMs $TimeoutMs) { return $true }
    }
    return $false
}
