#Requires -Version 5.0

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'FailoverLogic.ps1')
. (Join-Path $root 'WidgetLogic.ps1')

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

function New-FeedItem {
    param([string]$Id, [string]$Kind, [string]$Title, [string]$Body, [string]$PublishedAt)
    [pscustomobject]@{
        Id = $Id
        Kind = $Kind
        Title = $Title
        Body = $Body
        PublishedAt = $PublishedAt
        Url = ''
    }
}

$temp = Join-Path ([System.IO.Path]::GetTempPath()) ("desktop-widget-" + [guid]::NewGuid().ToString('N'))
[void][System.IO.Directory]::CreateDirectory($temp)
try {
    $example = Import-WidgetFeed ([System.IO.File]::ReadAllText((Join-Path $root 'news.example.json')))
    Assert-Equal 'example feed count' @($example).Count 2
    Assert-Equal 'maintenance sorts first' @($example)[0].Kind 'maintenance'
    Assert-Equal 'example maintenance title' @($example)[0].Title 'Почта будет недоступна'

    $parsed = Import-WidgetFeed '{"items":[{"type":"work","name":"Сеть","text":"Пауза","startsAt":"2026-10-01T10:00:00Z"},{"title":"Без номера","body":"Текст"}]}'
    Assert-Equal 'work kind is maintenance' @($parsed)[0].Kind 'maintenance'
    Assert-Equal 'title alias' @($parsed)[0].Title 'Сеть'
    $stableA = (Get-StableFeedId -Kind 'news' -Title 'Без номера' -PublishedAt '' -Body 'Текст')
    $stableB = (Get-StableFeedId -Kind 'news' -Title 'Без номера' -PublishedAt '' -Body 'Текст')
    Assert-Equal 'stable id' $stableA $stableB
    Assert-Equal 'missing id is stable' @($parsed)[1].Id $stableA

    $round = Import-WidgetFeed (ConvertTo-FeedJson @($parsed)[0])
    Assert-Equal 'one item roundtrip' @($round)[0].Title 'Сеть'

    $batch = Get-NotificationBatch -Items $example -FirstLoad $true
    Assert-Equal 'first load notifies maintenance only' $batch.Count 1
    Assert-Equal 'first load kind' $batch[0].Kind 'maintenance'
    $later = Get-NotificationBatch -Items $example -FirstLoad $false -Limit 3
    Assert-Equal 'later batch can include news' $later.Count 2

    $note = Format-FeedNotification ([pscustomobject]@{ Kind = 'maintenance'; Title = 'Почта'; Body = ('А' * 200) })
    Assert-True 'notification title' ($note.Title.Contains('Технические работы'))
    Assert-Equal 'notification length' $note.Text.Length 180

    $statePath = Join-Path $temp 'widget-state.json'
    $bridge = @{
        ItemsJson = ''
        FreshJson = ''
        FeedGeneration = 0
        UnreadCount = 0
        FromCache = $false
        FeedMessage = ''
    }
    $first = Publish-WidgetFeed -Items $example -FromCache $false -Message '' -Bridge $bridge -StatePath $statePath
    Assert-Equal 'first toast is one maintenance' @($first.Toast).Count 1
    Assert-Equal 'first unread is both' $first.UnreadCount 2
    Assert-True 'feed initialized' $first.Initialized
    Assert-Equal 'generation bumped' $bridge.FeedGeneration 1
    $second = Publish-WidgetFeed -Items $example -FromCache $false -Message '' -Bridge $bridge -StatePath $statePath
    Assert-Equal 'second publish does not toast backlog' @($second.Toast).Count 0
    Assert-Equal 'generation stays' $bridge.FeedGeneration 1

    Add-WidgetReadId -Path $statePath -Id @($example)[1].Id
    $state = Read-WidgetState $statePath
    Assert-Equal 'one item read' (ConvertTo-StringArray $state.ReadIds).Count 1
    Assert-Equal 'unread after open' (Get-WidgetUnreadCount -Items $example -ReadIds $state.ReadIds) 1

    $extra = @($example) + (New-FeedItem -Id 'news-2' -Kind 'news' -Title 'Новая' -Body 'Текст' -PublishedAt '2026-10-11T08:00:00Z')
    $third = Publish-WidgetFeed -Items $extra -FromCache $false -Message '' -Bridge $bridge -StatePath $statePath
    Assert-Equal 'new item is toasted' @($third.Toast).Count 1
    Assert-Equal 'new item id' @($third.Toast)[0].Id 'news-2'
    Assert-Equal 'generation grows' $bridge.FeedGeneration 2

    $newsOnly = @(New-FeedItem -Id 'n1' -Kind 'news' -Title 'Только новость' -Body 'А' -PublishedAt '2026-10-01T00:00:00Z')
    $quietBridge = @{ FeedGeneration = 0; ItemsJson = ''; FreshJson = ''; UnreadCount = 0; FromCache = $false; FeedMessage = '' }
    $quiet = Publish-WidgetFeed -Items $newsOnly -FromCache $false -Message '' -Bridge $quietBridge -StatePath (Join-Path $temp 'quiet.json')
    Assert-Equal 'first news does not toast' @($quiet.Toast).Count 0
    Assert-Equal 'first news stays unread' $quiet.UnreadCount 1
    Assert-Equal 'no generation for quiet first load' $quietBridge.FeedGeneration 0
    $quietAgain = Publish-WidgetFeed -Items $newsOnly -FromCache $false -Message '' -Bridge $quietBridge -StatePath (Join-Path $temp 'quiet.json')
    Assert-Equal 'single stored id does not toast again' @($quietAgain.Toast).Count 0

    Assert-Throws 'empty summary' { Normalize-TicketSummary '   ' }
    $long = 'Я' * 300
    Assert-Equal 'summary limit' (Normalize-TicketSummary $long).Length 255
    $body = New-ServiceDeskRequestBody -ServiceDeskId '1' -RequestTypeId '10' -Summary '  Не печатает  ' -Description 'Принтер молчит'
    Assert-Equal 'desk id' $body.serviceDeskId '1'
    Assert-Equal 'summary trimmed' $body.requestFieldValues.summary 'Не печатает'
    Assert-Equal 'issue key' (Get-ServiceDeskIssueKey '{"issueKey":"SD-15"}') 'SD-15'
    Assert-Throws 'desk ids required' { New-ServiceDeskRequestBody -ServiceDeskId '' -RequestTypeId '1' -Summary 'Тема' -Description '' }

    $outbox = Join-Path $temp 'outbox.json'
    Add-OutboxTicket -Path $outbox -Summary 'Первая' -Description 'А' | Out-Null
    Add-OutboxTicket -Path $outbox -Summary 'Вторая' -Description 'Б' | Out-Null
    $failed = Send-OutboxTickets -Path $outbox -Send { param($Ticket) [pscustomobject]@{ Ok = $false; Key = ''; Message = 'нет' } }
    Assert-Equal 'failed send keeps both' $failed.Pending 2
    Assert-Equal 'file still has both' (Read-OutboxTickets $outbox).Count 2
    $calls = 0
    $partial = Send-OutboxTickets -Path $outbox -Send {
        param($Ticket)
        $script:SendCalls++
        if ($Ticket.Summary -eq 'Первая') { return [pscustomobject]@{ Ok = $true; Key = 'SD-1'; Message = 'ok' } }
        return [pscustomobject]@{ Ok = $false; Key = ''; Message = 'позже' }
    }
    Assert-Equal 'one key sent' @($partial.Sent).Count 1
    Assert-Equal 'second stays' $partial.Pending 1
    Assert-Equal 'remaining summary' (Read-OutboxTickets $outbox)[0].Summary 'Вторая'

    $feedFile = Join-Path $temp 'feed.json'
    [System.IO.File]::WriteAllText($feedFile, [System.IO.File]::ReadAllText((Join-Path $root 'news.example.json')))
    $snapshot = Read-WidgetFeedSnapshot -FeedUrl $feedFile -CachePath (Join-Path $temp 'cache.json') -AllowNetwork $true
    Assert-True 'file feed is live' (-not $snapshot.FromCache)
    Assert-Equal 'file feed count' @($snapshot.Items).Count 2
    $cached = Read-WidgetFeedSnapshot -FeedUrl (Join-Path $temp 'missing.json') -CachePath (Join-Path $temp 'cache.json') -AllowNetwork $true
    Assert-True 'missing feed uses cache' $cached.FromCache
    Assert-Equal 'cache count' @($cached.Items).Count 2
    $offlineShare = Read-WidgetFeedSnapshot -FeedUrl '\\fileserver\share\news.json' -CachePath (Join-Path $temp 'cache.json') -AllowNetwork $false
    Assert-True 'offline share uses cache' $offlineShare.FromCache

    $widget = Import-WidgetConfig (Join-Path $root 'config.example.json')
    Assert-True 'widget enabled' $widget.Enabled
    Assert-Equal 'widget title' $widget.Title 'Сервис-деск'
    Assert-Equal 'feed poll' $widget.FeedPollSeconds 300
    Assert-Throws 'bad portal' { ConvertTo-WidgetConfig ([pscustomobject]@{ widget = [pscustomobject]@{ portalUrl = 'ftp://jira' } }) }
    Assert-Equal 'offline status' (Format-WidgetStatus -Mode 'Offline' -OutboxCount 1) 'Локальный рабочий стол. Заявка ждёт отправки: 1.'
    Assert-Equal 'online status' (Format-WidgetStatus -Mode 'Online') 'Сетевой рабочий стол'
    $trimmed = Format-WidgetStatus -ErrorMessage ('Ошибка ' + ('х' * 120))
    Assert-Equal 'long status' $trimmed.Length 90
} finally {
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}

$feedJson = [System.IO.File]::ReadAllText((Join-Path $root 'news.example.json'))
try {
    $feedListener = New-Object System.Net.HttpListener
    $feedListener.Prefixes.Add('http://127.0.0.1:18771/')
    $feedListener.Start()
    $feedRunspace = [runspacefactory]::CreateRunspace()
    $feedRunspace.Open()
    $feedWorker = [powershell]::Create()
    $feedWorker.Runspace = $feedRunspace
    [void]$feedWorker.AddScript({
        param($Server, $Payload)
        $context = $Server.GetContext()
        $buffer = [Text.Encoding]::UTF8.GetBytes($Payload)
        $context.Response.StatusCode = 200
        $context.Response.ContentType = 'application/json'
        $context.Response.OutputStream.Write($buffer, 0, $buffer.Length)
        $context.Response.Close()
    }).AddArgument($feedListener).AddArgument($feedJson)
    $feedHandle = $feedWorker.BeginInvoke()
    $httpCache = Join-Path ([System.IO.Path]::GetTempPath()) 'widget-http-cache.json'
    $httpFeed = Read-WidgetFeedSnapshot -FeedUrl 'http://127.0.0.1:18771/news' -CachePath $httpCache -AllowNetwork $true -TimeoutMs 5000
    Assert-True 'http feed is live' (-not $httpFeed.FromCache)
    Assert-Equal 'http feed count' @($httpFeed.Items).Count 2
    if (-not $feedHandle.IsCompleted) { $feedWorker.Stop() }
    $feedWorker.Dispose()
    $feedListener.Stop()
    $feedListener.Close()
    $feedRunspace.Dispose()
    Remove-Item -LiteralPath $httpCache -Force -ErrorAction SilentlyContinue

    $deskListener = New-Object System.Net.HttpListener
    $deskListener.Prefixes.Add('http://127.0.0.1:18772/')
    $deskListener.Start()
    $deskRunspace = [runspacefactory]::CreateRunspace()
    $deskRunspace.Open()
    $deskWorker = [powershell]::Create()
    $deskWorker.Runspace = $deskRunspace
    $deskBodyPath = Join-Path ([System.IO.Path]::GetTempPath()) ("widget-post-" + [guid]::NewGuid().ToString('N') + '.txt')
    [void]$deskWorker.AddScript({
        param($Server, $BodyPath)
        $context = $Server.GetContext()
        $reader = New-Object System.IO.StreamReader($context.Request.InputStream, [Text.Encoding]::UTF8)
        [System.IO.File]::WriteAllText($BodyPath, $reader.ReadToEnd())
        $reader.Close()
        $buffer = [Text.Encoding]::UTF8.GetBytes('{"issueKey":"SD-15"}')
        $context.Response.StatusCode = 201
        $context.Response.ContentType = 'application/json'
        $context.Response.OutputStream.Write($buffer, 0, $buffer.Length)
        $context.Response.Close()
    }).AddArgument($deskListener).AddArgument($deskBodyPath)
    $deskHandle = $deskWorker.BeginInvoke()
    $created = Invoke-ServiceDeskRequest -ApiBaseUrl 'http://127.0.0.1:18772' -ServiceDeskId '1' -RequestTypeId '10' -Summary 'Не печатает' -Description 'Принтер' -TimeoutMs 5000
    Assert-True 'ticket created' $created.Ok
    Assert-Equal 'ticket key' $created.Key 'SD-15'
    $posted = ''
    if ([System.IO.File]::Exists($deskBodyPath)) { $posted = [System.IO.File]::ReadAllText($deskBodyPath) }
    Assert-True 'ticket body has summary' ($posted.Contains('Не печатает'))
    Assert-True 'ticket body has desk' ($posted.Contains('requestTypeId'))
    if (-not $deskHandle.IsCompleted) { $deskWorker.Stop() }
    $deskWorker.Dispose()
    $deskListener.Stop()
    $deskListener.Close()
    $deskRunspace.Dispose()
    Remove-Item -LiteralPath $deskBodyPath -Force -ErrorAction SilentlyContinue
} catch {
    Write-Host "skip http widget: $($_.Exception.Message)"
    Assert-True 'http widget checks did not throw' $false
}

Write-Host ""
Write-Host ("passed: {0}  failed: {1}" -f $script:Pass, $script:Fail)
if ($script:Fail -gt 0) { exit 1 }
exit 0
