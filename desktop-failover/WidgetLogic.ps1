#Requires -Version 5.0

function Get-DefaultWidgetConfig {
    [pscustomobject]@{
        Enabled = $true
        Title = 'Сервис-деск'
        PortalUrl = ''
        ApiBaseUrl = ''
        ServiceDeskId = ''
        RequestTypeId = ''
        FeedUrl = ''
        FeedPollSeconds = 300
    }
}

function Test-WidgetAddress {
    param(
        [string]$Value,
        [switch]$AllowFile
    )
    if ([string]::IsNullOrWhiteSpace($Value)) { return }
    $text = $Value.Trim()
    if ($text -match '^https?://') { return }
    $localFile = (Test-IsUncPath $text) -or ($text -match '^[A-Za-z]:[\\/]') -or [System.IO.Path]::IsPathRooted($text)
    if ($AllowFile -and $localFile) { return }
    if ($AllowFile) {
        throw "Адрес ленты должен быть http(s) или путём к файлу: $text"
    }
    throw "Адрес должен начинаться с http:// или https://: $text"
}

function ConvertTo-WidgetConfig {
    param($Raw)
    $defaults = Get-DefaultWidgetConfig
    $source = $Raw
    if ($null -ne $Raw) {
        $nested = Get-Prop $Raw 'widget' $null
        if ($null -ne $nested) { $source = $nested }
    }
    if ($null -eq $source) { return $defaults }
    $portal = ([string](Get-Prop $source 'portalUrl' $defaults.PortalUrl)).Trim()
    $api = ([string](Get-Prop $source 'apiBaseUrl' $defaults.ApiBaseUrl)).Trim().TrimEnd('/')
    $feed = ([string](Get-Prop $source 'feedUrl' $defaults.FeedUrl)).Trim()
    Test-WidgetAddress $portal
    Test-WidgetAddress $api
    Test-WidgetAddress $feed -AllowFile
    $title = ([string](Get-Prop $source 'title' $defaults.Title)).Trim()
    if ([string]::IsNullOrWhiteSpace($title)) { $title = $defaults.Title }
    [pscustomobject]@{
        Enabled = ConvertTo-BoolValue (Get-Prop $source 'enabled' $defaults.Enabled) $defaults.Enabled
        Title = $title
        PortalUrl = $portal
        ApiBaseUrl = $api
        ServiceDeskId = ([string](Get-Prop $source 'serviceDeskId' $defaults.ServiceDeskId)).Trim()
        RequestTypeId = ([string](Get-Prop $source 'requestTypeId' $defaults.RequestTypeId)).Trim()
        FeedUrl = $feed
        FeedPollSeconds = [int](ConvertTo-BoundedInt (Get-Prop $source 'feedPollSeconds' $defaults.FeedPollSeconds) $defaults.FeedPollSeconds 30 86400 'feedPollSeconds')
    }
}

function Import-WidgetConfig {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path) -or -not [System.IO.File]::Exists($Path)) {
        return Get-DefaultWidgetConfig
    }
    $raw = [System.IO.File]::ReadAllText($Path) | ConvertFrom-Json
    return ConvertTo-WidgetConfig $raw
}

function Get-EmptyWidgetState {
    [pscustomobject]@{
        Initialized = $false
        NotifiedIds = @()
        ReadIds = @()
    }
}

function Invoke-WidgetFileLock {
    param([scriptblock]$Action)
    $mutex = New-Object System.Threading.Mutex($false, 'DesktopFailover.WidgetState')
    $owned = $false
    try {
        try {
            $owned = $mutex.WaitOne(8000)
        } catch [System.Threading.AbandonedMutexException] {
            $owned = $true
        }
        if (-not $owned) { throw 'Не удалось открыть данные виджета.' }
        return (& $Action)
    } finally {
        if ($owned) {
            try { [void]$mutex.ReleaseMutex() } catch {}
        }
        $mutex.Dispose()
    }
}

function Read-WidgetStateFile {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path) -or -not [System.IO.File]::Exists($Path)) {
        return Get-EmptyWidgetState
    }
    $raw = [System.IO.File]::ReadAllText($Path) | ConvertFrom-Json
    [pscustomobject]@{
        Initialized = ConvertTo-BoolValue (Get-Prop $raw 'initialized' $false) $false
        NotifiedIds = ConvertTo-StringArray (Get-Prop $raw 'notifiedIds' @())
        ReadIds = ConvertTo-StringArray (Get-Prop $raw 'readIds' @())
    }
}

function Write-WidgetStateFile {
    param($State, [string]$Path)
    $directory = [System.IO.Path]::GetDirectoryName($Path)
    if (-not [string]::IsNullOrWhiteSpace($directory)) {
        [void][System.IO.Directory]::CreateDirectory($directory)
    }
    $payload = [ordered]@{
        initialized = [bool]$State.Initialized
        notifiedIds = ConvertTo-StringArray $State.NotifiedIds
        readIds = ConvertTo-StringArray $State.ReadIds
    }
    $json = $payload | ConvertTo-Json -Depth 4
    $encoding = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($Path, $json, $encoding)
}

function Read-WidgetState {
    param([string]$Path)
    return Invoke-WidgetFileLock { Read-WidgetStateFile $Path }
}

function Write-WidgetState {
    param($State, [string]$Path)
    Invoke-WidgetFileLock { Write-WidgetStateFile -State $State -Path $Path } | Out-Null
}

function Get-StableFeedId {
    param(
        [string]$Kind,
        [string]$Title,
        [string]$PublishedAt,
        [string]$Body
    )
    $material = "$Kind|$Title|$PublishedAt|$Body"
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($material))
    } finally {
        $sha.Dispose()
    }
    return -join ($bytes[0..7] | ForEach-Object { $_.ToString('x2') })
}

function ConvertTo-FeedKind {
    param([string]$Value)
    $text = ''
    if (-not [string]::IsNullOrWhiteSpace($Value)) { $text = $Value.Trim().ToLowerInvariant() }
    switch ($text) {
        'maintenance' { return 'maintenance' }
        'work' { return 'maintenance' }
        'works' { return 'maintenance' }
        'technical' { return 'maintenance' }
        'outage' { return 'maintenance' }
        default { return 'news' }
    }
}

function ConvertTo-FeedDateTicks {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return [int64]::MinValue }
    try {
        $parsed = [datetime]::Parse(
            $Text,
            [Globalization.CultureInfo]::InvariantCulture,
            [Globalization.DateTimeStyles]::RoundtripKind)
        return $parsed.ToUniversalTime().Ticks
    } catch {
        try { return ([datetime]$Text).ToUniversalTime().Ticks } catch { return [int64]::MinValue }
    }
}

function Import-WidgetFeed {
    param($Json)
    if ($null -eq $Json -or [string]::IsNullOrWhiteSpace([string]$Json)) {
        return ,@()
    }
    $raw = [string]$Json | ConvertFrom-Json
    $rows = @()
    if ($raw -is [System.Array]) {
        $rows = @($raw)
    } else {
        $node = Get-Prop $raw 'items' $null
        if ($null -eq $node) { throw 'В ленте нет списка items.' }
        $rows = @($node)
    }
    $items = New-Object System.Collections.Generic.List[object]
    foreach ($row in $rows) {
        if ($null -eq $row) { continue }
        $kind = ConvertTo-FeedKind (Get-Prop $row 'kind' (Get-Prop $row 'type' 'news'))
        $title = ([string](Get-Prop $row 'title' (Get-Prop $row 'name' ''))).Trim()
        $body = [string](Get-Prop $row 'body' (Get-Prop $row 'text' (Get-Prop $row 'message' '')))
        $published = [string](Get-Prop $row 'publishedAt' (Get-Prop $row 'date' (Get-Prop $row 'startsAt' '')))
        $url = ([string](Get-Prop $row 'url' (Get-Prop $row 'link' ''))).Trim()
        $id = ([string](Get-Prop $row 'id' '')).Trim()
        if ([string]::IsNullOrWhiteSpace($id)) {
            $id = Get-StableFeedId -Kind $kind -Title $title -PublishedAt $published -Body $body
        }
        if (-not [string]::IsNullOrWhiteSpace($url)) { Test-WidgetAddress $url }
        $items.Add([pscustomobject]@{
            Id = $id
            Kind = $kind
            Title = $title
            Body = $body
            PublishedAt = $published
            Url = $url
        })
    }
    return ,(Sort-WidgetFeedItems $items.ToArray())
}

function Sort-WidgetFeedItems {
    param($Items)
    $decorated = New-Object System.Collections.Generic.List[object]
    foreach ($item in @($Items)) {
        if ($null -eq $item) { continue }
        $rank = 1
        if ($item.Kind -eq 'maintenance') { $rank = 0 }
        $decorated.Add([pscustomobject]@{
            Item = $item
            Rank = $rank
            Ticks = (ConvertTo-FeedDateTicks $item.PublishedAt)
        })
    }
    $ordered = @($decorated | Sort-Object Rank, @{ Expression = 'Ticks'; Descending = $true })
    $result = New-Object System.Collections.Generic.List[object]
    foreach ($row in $ordered) {
        if ($null -eq $row) { continue }
        $result.Add($row.Item)
    }
    return ,$result.ToArray()
}

function ConvertTo-FeedJson {
    param($Items)
    $rows = New-Object System.Collections.Generic.List[object]
    foreach ($item in @($Items)) {
        if ($null -eq $item) { continue }
        $rows.Add([ordered]@{
            id = [string]$item.Id
            kind = [string]$item.Kind
            title = [string]$item.Title
            body = [string]$item.Body
            publishedAt = [string]$item.PublishedAt
            url = [string]$item.Url
        })
    }
    $payload = [pscustomobject]@{ items = @($rows.ToArray()) }
    return ($payload | ConvertTo-Json -Depth 5 -Compress)
}

function Get-NotificationBatch {
    param(
        $Items,
        [bool]$FirstLoad,
        [int]$Limit = 3
    )
    $max = $Limit
    if ($FirstLoad) { $max = 2 }
    if ($max -lt 1) { $max = 1 }
    $result = New-Object System.Collections.Generic.List[object]
    foreach ($item in @($Items)) {
        if ($null -eq $item) { continue }
        if ($FirstLoad -and $item.Kind -ne 'maintenance') { continue }
        $result.Add($item)
        if ($result.Count -ge $max) { break }
    }
    return ,$result.ToArray()
}

function Get-WidgetUnreadCount {
    param($Items, $ReadIds)
    $read = @{}
    foreach ($id in (ConvertTo-StringArray $ReadIds)) { $read[$id] = $true }
    $count = 0
    foreach ($item in @($Items)) {
        if ($null -eq $item) { continue }
        if (-not $read.ContainsKey([string]$item.Id)) { $count++ }
    }
    return $count
}

function Add-WidgetReadId {
    param(
        [string]$Path,
        [string]$Id
    )
    if ([string]::IsNullOrWhiteSpace($Id)) { return }
    Invoke-WidgetFileLock {
        $state = Read-WidgetStateFile $Path
        $ids = ConvertTo-StringArray $state.ReadIds
        if ($ids -notcontains $Id) {
            $state.ReadIds = @($ids + $Id)
            Write-WidgetStateFile -State $state -Path $Path
        }
    } | Out-Null
}

function Publish-WidgetFeed {
    param(
        $Items,
        [bool]$FromCache,
        [string]$Message,
        $Bridge,
        [string]$StatePath
    )
    $published = Invoke-WidgetFileLock {
        $state = Read-WidgetStateFile $StatePath
        $notified = @{}
        foreach ($id in (ConvertTo-StringArray $state.NotifiedIds)) { $notified[$id] = $true }
        $fresh = New-Object System.Collections.Generic.List[object]
        foreach ($item in @($Items)) {
            if ($null -eq $item) { continue }
            if (-not $notified.ContainsKey([string]$item.Id)) { [void]$fresh.Add($item) }
        }
        $batch = Get-NotificationBatch -Items $fresh.ToArray() -FirstLoad:(-not $state.Initialized)
        $mark = New-Object System.Collections.Generic.List[string]
        foreach ($id in @($notified.Keys)) { [void]$mark.Add([string]$id) }
        if (-not $state.Initialized) {
            foreach ($item in $fresh) {
                if ($null -eq $item) { continue }
                [void]$mark.Add([string]$item.Id)
            }
            $state.Initialized = $true
        } else {
            foreach ($item in @($batch)) {
                if ($null -eq $item) { continue }
                [void]$mark.Add([string]$item.Id)
            }
        }
        $state.NotifiedIds = @($mark.ToArray())
        Write-WidgetStateFile -State $state -Path $StatePath
        $unread = Get-WidgetUnreadCount -Items $Items -ReadIds $state.ReadIds
        [pscustomobject]@{
            Toast = @($batch)
            UnreadCount = $unread
            Initialized = [bool]$state.Initialized
        }
    }
    $toastItems = @($published.Toast | Where-Object { $null -ne $_ })
    if ($null -ne $Bridge) {
        $Bridge.ItemsJson = ConvertTo-FeedJson $Items
        $Bridge.UnreadCount = [int]$published.UnreadCount
        $Bridge.FromCache = [bool]$FromCache
        $Bridge.FeedMessage = [string]$Message
        if ($toastItems.Count -gt 0) {
            $Bridge.FreshJson = ConvertTo-FeedJson $toastItems
            $Bridge.FeedGeneration = [int]$Bridge.FeedGeneration + 1
        }
    }
    [pscustomobject]@{
        Toast = $toastItems
        UnreadCount = [int]$published.UnreadCount
        Initialized = [bool]$published.Initialized
    }
}

function Format-FeedKindLabel {
    param([string]$Kind)
    if ($Kind -eq 'maintenance') { return 'Технические работы' }
    return 'Новость'
}

function Format-FeedNotification {
    param($Item)
    $title = Format-FeedKindLabel $Item.Kind
    if (-not [string]::IsNullOrWhiteSpace([string]$Item.Title)) {
        $title = "$title. $($Item.Title)"
    }
    $text = [string]$Item.Body
    $text = ($text -replace '\s+', ' ').Trim()
    if ($text.Length -gt 180) { $text = $text.Substring(0, 177) + '...' }
    if ([string]::IsNullOrWhiteSpace($text)) { $text = $title }
    [pscustomobject]@{
        Title = $title
        Text = $text
    }
}

function Format-WidgetStatus {
    param(
        [string]$Mode,
        [string]$ErrorMessage,
        [int]$OutboxCount = 0
    )
    if (-not [string]::IsNullOrWhiteSpace($ErrorMessage)) {
        $text = ($ErrorMessage -replace '\s+', ' ').Trim()
        if ($text.Length -gt 90) { return $text.Substring(0, 87) + '...' }
        return $text
    }
    $base = 'Сетевой рабочий стол'
    if ($Mode -eq 'Offline') { $base = 'Локальный рабочий стол' }
    if ($OutboxCount -gt 0) { return "$base. Заявка ждёт отправки: $OutboxCount." }
    return $base
}

function Format-FeedCaption {
    param($Item)
    $label = Format-FeedKindLabel $Item.Kind
    if ([string]::IsNullOrWhiteSpace([string]$Item.Title)) { return $label }
    return "$label — $($Item.Title)"
}

function Normalize-TicketSummary {
    param([string]$Summary)
    $text = ''
    if (-not [string]::IsNullOrWhiteSpace($Summary)) {
        $text = ($Summary -replace '\s+', ' ').Trim()
    }
    if ([string]::IsNullOrWhiteSpace($text)) { throw 'Укажите тему заявки.' }
    if ($text.Length -gt 255) { $text = $text.Substring(0, 255).Trim() }
    return $text
}

function New-ServiceDeskRequestBody {
    param(
        [string]$ServiceDeskId,
        [string]$RequestTypeId,
        [string]$Summary,
        [string]$Description
    )
    if ([string]::IsNullOrWhiteSpace($ServiceDeskId) -or [string]::IsNullOrWhiteSpace($RequestTypeId)) {
        throw 'Укажите serviceDeskId и requestTypeId в config.json.'
    }
    $summaryText = Normalize-TicketSummary $Summary
    $descriptionText = ''
    if (-not [string]::IsNullOrWhiteSpace($Description)) { $descriptionText = $Description.Trim() }
    [ordered]@{
        serviceDeskId = $ServiceDeskId.Trim()
        requestTypeId = $RequestTypeId.Trim()
        requestFieldValues = [ordered]@{
            summary = $summaryText
            description = $descriptionText
        }
    }
}

function Get-ServiceDeskIssueKey {
    param([string]$Json)
    if ([string]::IsNullOrWhiteSpace($Json)) { return '' }
    $raw = $Json | ConvertFrom-Json
    $key = [string](Get-Prop $raw 'issueKey' '')
    if ([string]::IsNullOrWhiteSpace($key)) { $key = [string](Get-Prop $raw 'key' '') }
    return $key.Trim()
}

function Read-HttpText {
    param(
        [string]$Url,
        [string]$Method = 'GET',
        [string]$Body = '',
        [int]$TimeoutMs = 15000
    )
    $request = [System.Net.HttpWebRequest]::Create($Url)
    $request.Method = $Method
    $request.Timeout = $TimeoutMs
    $request.ReadWriteTimeout = $TimeoutMs
    $request.AllowAutoRedirect = ($Method -eq 'GET')
    $request.Accept = 'application/json'
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
    if ($Method -ne 'GET') {
        $request.ContentType = 'application/json; charset=utf-8'
        $request.Headers['X-Atlassian-Token'] = 'no-check'
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Body)
        $request.ContentLength = $bytes.Length
        $stream = $request.GetRequestStream()
        try { $stream.Write($bytes, 0, $bytes.Length) } finally { $stream.Close() }
    }
    $response = $null
    try {
        $response = $request.GetResponse()
        $reader = New-Object System.IO.StreamReader($response.GetResponseStream(), [System.Text.Encoding]::UTF8)
        try { return $reader.ReadToEnd() } finally { $reader.Close() }
    } catch [System.Net.WebException] {
        $errorResponse = $_.Exception.Response
        $detail = $_.Exception.Message
        if ($null -ne $errorResponse) {
            try {
                $errorReader = New-Object System.IO.StreamReader($errorResponse.GetResponseStream(), [System.Text.Encoding]::UTF8)
                try {
                    $payload = $errorReader.ReadToEnd()
                    if (-not [string]::IsNullOrWhiteSpace($payload)) { $detail = $payload }
                } finally { $errorReader.Close() }
            } catch {}
        }
        throw $detail
    } finally {
        if ($null -ne $response) { $response.Close() }
    }
}

function Read-FeedDocument {
    param(
        [string]$FeedUrl,
        [int]$TimeoutMs = 15000
    )
    if ([string]::IsNullOrWhiteSpace($FeedUrl)) { throw 'Лента новостей не задана.' }
    Test-WidgetAddress $FeedUrl -AllowFile
    if ($FeedUrl -match '^https?://') {
        return Read-HttpText -Url $FeedUrl -TimeoutMs $TimeoutMs
    }
    if (-not [System.IO.File]::Exists($FeedUrl)) { throw "Файл ленты не найден: $FeedUrl" }
    return [System.IO.File]::ReadAllText($FeedUrl)
}

function Save-WidgetFeedCache {
    param(
        $Items,
        [string]$Path
    )
    $directory = [System.IO.Path]::GetDirectoryName($Path)
    if (-not [string]::IsNullOrWhiteSpace($directory)) {
        [void][System.IO.Directory]::CreateDirectory($directory)
    }
    $encoding = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($Path, (ConvertTo-FeedJson $Items), $encoding)
}

function Read-WidgetFeedCache {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path) -or -not [System.IO.File]::Exists($Path)) { return ,@() }
    return Import-WidgetFeed ([System.IO.File]::ReadAllText($Path))
}

function Read-WidgetFeedSnapshot {
    param(
        [string]$FeedUrl,
        [string]$CachePath,
        [bool]$AllowNetwork = $true,
        [int]$TimeoutMs = 15000
    )
    try {
        if ([string]::IsNullOrWhiteSpace($FeedUrl)) { throw 'Лента новостей не задана.' }
        if (-not $AllowNetwork) { throw 'Сетевая папка ленты сейчас недоступна.' }
        $json = Read-FeedDocument -FeedUrl $FeedUrl -TimeoutMs $TimeoutMs
        $items = Import-WidgetFeed $json
        if (-not [string]::IsNullOrWhiteSpace($CachePath)) {
            Save-WidgetFeedCache -Items $items -Path $CachePath
        }
        return [pscustomobject]@{
            Items = $items
            FromCache = $false
            Message = ''
        }
    } catch {
        $cached = @()
        if (-not [string]::IsNullOrWhiteSpace($CachePath)) {
            try { $cached = Read-WidgetFeedCache $CachePath } catch { $cached = @() }
        }
        return [pscustomobject]@{
            Items = $cached
            FromCache = $true
            Message = [string]$_.Exception.Message
        }
    }
}

function Invoke-ServiceDeskRequest {
    param(
        [string]$ApiBaseUrl,
        [string]$ServiceDeskId,
        [string]$RequestTypeId,
        [string]$Summary,
        [string]$Description,
        [int]$TimeoutMs = 15000
    )
    Test-WidgetAddress $ApiBaseUrl
    if ([string]::IsNullOrWhiteSpace($ApiBaseUrl)) { throw 'Адрес Jira не задан.' }
    $body = New-ServiceDeskRequestBody -ServiceDeskId $ServiceDeskId -RequestTypeId $RequestTypeId -Summary $Summary -Description $Description
    $json = $body | ConvertTo-Json -Depth 5 -Compress
    $url = $ApiBaseUrl.TrimEnd('/') + '/rest/servicedeskapi/request'
    try {
        $responseText = Read-HttpText -Url $url -Method 'POST' -Body $json -TimeoutMs $TimeoutMs
    } catch {
        return [pscustomobject]@{
            Ok = $false
            Key = ''
            Message = [string]$_.Exception.Message
        }
    }
    $key = Get-ServiceDeskIssueKey $responseText
    if ([string]::IsNullOrWhiteSpace($key)) {
        return [pscustomobject]@{
            Ok = $false
            Key = ''
            Message = 'Сервис-деск не вернул номер заявки.'
        }
    }
    [pscustomobject]@{
        Ok = $true
        Key = $key
        Message = "Заявка создана: $key"
    }
}

function Read-OutboxTickets {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path) -or -not [System.IO.File]::Exists($Path)) { return ,@() }
    $raw = [System.IO.File]::ReadAllText($Path) | ConvertFrom-Json
    $rows = @(Get-Prop $raw 'tickets' @())
    $items = New-Object System.Collections.Generic.List[object]
    foreach ($row in $rows) {
        if ($null -eq $row) { continue }
        $items.Add([pscustomobject]@{
            Id = [string](Get-Prop $row 'id' '')
            Summary = [string](Get-Prop $row 'summary' '')
            Description = [string](Get-Prop $row 'description' '')
            CreatedUtc = [string](Get-Prop $row 'createdUtc' '')
        })
    }
    return ,$items.ToArray()
}

function Write-OutboxTickets {
    param($Tickets, [string]$Path)
    $directory = [System.IO.Path]::GetDirectoryName($Path)
    if (-not [string]::IsNullOrWhiteSpace($directory)) {
        [void][System.IO.Directory]::CreateDirectory($directory)
    }
    $rows = New-Object System.Collections.Generic.List[object]
    foreach ($ticket in @($Tickets)) {
        if ($null -eq $ticket) { continue }
        $rows.Add([ordered]@{
            id = [string]$ticket.Id
            summary = [string]$ticket.Summary
            description = [string]$ticket.Description
            createdUtc = [string]$ticket.CreatedUtc
        })
    }
    $json = ([pscustomobject]@{ tickets = @($rows.ToArray()) }) | ConvertTo-Json -Depth 5
    $encoding = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($Path, $json, $encoding)
}

function Add-OutboxTicket {
    param(
        [string]$Path,
        [string]$Summary,
        [string]$Description
    )
    $summaryText = Normalize-TicketSummary $Summary
    $descriptionText = ''
    if (-not [string]::IsNullOrWhiteSpace($Description)) { $descriptionText = $Description.Trim() }
    return Invoke-WidgetFileLock {
        $existing = Read-OutboxTickets $Path
        $ticket = [pscustomobject]@{
            Id = [guid]::NewGuid().ToString('N')
            Summary = $summaryText
            Description = $descriptionText
            CreatedUtc = [datetime]::UtcNow.ToString('o')
        }
        Write-OutboxTickets -Tickets @($existing + $ticket) -Path $Path
        return $ticket
    }
}

function Send-OutboxTickets {
    param(
        [string]$Path,
        [scriptblock]$Send
    )
    $pending = Read-OutboxTickets $Path
    $kept = New-Object System.Collections.Generic.List[object]
    $sent = New-Object System.Collections.Generic.List[string]
    $failed = 0
    $stop = $false
    foreach ($ticket in $pending) {
        if ($null -eq $ticket) { continue }
        if ($stop) { [void]$kept.Add($ticket); continue }
        $result = & $Send $ticket
        if ($result.Ok) {
            [void]$sent.Add([string]$result.Key)
        } else {
            $failed++
            [void]$kept.Add($ticket)
            $stop = $true
        }
    }
    Invoke-WidgetFileLock {
        $current = Read-OutboxTickets $Path
        $sentIds = @{}
        foreach ($ticket in $pending) {
            if ($null -eq $ticket) { continue }
            $still = $false
            foreach ($item in $kept) {
                if ($null -ne $item -and $item.Id -eq $ticket.Id) { $still = $true }
            }
            if (-not $still) { $sentIds[$ticket.Id] = $true }
        }
        $merged = New-Object System.Collections.Generic.List[object]
        foreach ($ticket in $current) {
            if ($null -eq $ticket) { continue }
            if ($sentIds.ContainsKey($ticket.Id)) { continue }
            [void]$merged.Add($ticket)
        }
        Write-OutboxTickets -Tickets $merged.ToArray() -Path $Path
    } | Out-Null
    [pscustomobject]@{
        Sent = @($sent.ToArray())
        Failed = $failed
        Pending = $kept.Count
    }
}
