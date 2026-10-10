#Requires -Version 5.0

$script:DesktopWidgetNativeCSharp = @'
using System;
using System.Runtime.InteropServices;

namespace DesktopWidgetNative
{
    public static class Host
    {
        public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

        [StructLayout(LayoutKind.Sequential)]
        public struct RECT
        {
            public int Left;
            public int Top;
            public int Right;
            public int Bottom;
        }

        static IntPtr foundHost = IntPtr.Zero;

        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);

        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        public static extern IntPtr FindWindowEx(IntPtr parent, IntPtr child, string cls, string window);

        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint Msg, UIntPtr wParam, IntPtr lParam, uint flags, uint timeout, out UIntPtr result);

        [DllImport("user32.dll")]
        public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);

        [DllImport("user32.dll")]
        public static extern IntPtr SetParent(IntPtr hWndChild, IntPtr hWndNewParent);

        [DllImport("user32.dll")]
        public static extern bool IsWindow(IntPtr hWnd);

        [DllImport("user32.dll")]
        public static extern bool GetClientRect(IntPtr hWnd, out RECT lpRect);

        [DllImport("user32.dll")]
        public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int x, int y, int cx, int cy, uint flags);

        public static void PlaceInParent(IntPtr child, IntPtr parent, int width, int height)
        {
            RECT rect;
            if (parent == IntPtr.Zero || !GetClientRect(parent, out rect)) return;
            int x = rect.Right - width - 24;
            int y = rect.Bottom - height - 80;
            if (x < 8) x = 8;
            if (y < 8) y = 8;
            SetWindowPos(child, IntPtr.Zero, x, y, width, height, 0x0014);
        }

        static bool OnEnum(IntPtr hWnd, IntPtr lParam)
        {
            IntPtr view = FindWindowEx(hWnd, IntPtr.Zero, "SHELLDLL_DefView", null);
            if (view != IntPtr.Zero)
            {
                IntPtr worker = FindWindowEx(IntPtr.Zero, hWnd, "WorkerW", null);
                if (worker != IntPtr.Zero) foundHost = worker;
                else foundHost = hWnd;
            }
            return true;
        }

        public static IntPtr FindDesktopHost()
        {
            foundHost = IntPtr.Zero;
            IntPtr progman = FindWindow("Progman", null);
            UIntPtr result;
            if (progman != IntPtr.Zero)
            {
                SendMessageTimeout(progman, 0x052C, UIntPtr.Zero, IntPtr.Zero, 2, 1000, out result);
            }
            EnumWindows(OnEnum, IntPtr.Zero);
            if (foundHost != IntPtr.Zero) return foundHost;
            return progman;
        }
    }
}
'@

function Initialize-WidgetUi {
    if (-not ('DesktopWidgetNative.Host' -as [type])) {
        Add-Type -TypeDefinition $script:DesktopWidgetNativeCSharp -Language CSharp -ErrorAction Stop
    }
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    [System.Windows.Forms.Application]::EnableVisualStyles()
    [System.Windows.Forms.Application]::SetCompatibleTextRenderingDefault($false)
}

function New-WidgetIcon {
    $bitmap = New-Object System.Drawing.Bitmap 32, 32
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.Clear([System.Drawing.Color]::FromArgb(18, 48, 82))
    $brush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(61, 220, 151))
    $graphics.FillEllipse($brush, 6, 6, 20, 20)
    $icon = [System.Drawing.Icon]::FromHandle($bitmap.GetHicon())
    $graphics.Dispose()
    return $icon
}

function Set-RoundedWidgetRegion {
    param($Form, [int]$Radius = 16)
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $diameter = $Radius * 2
    $width = $Form.Width
    $height = $Form.Height
    $path.AddArc(0, 0, $diameter, $diameter, 180, 90)
    $path.AddArc($width - $diameter, 0, $diameter, $diameter, 270, 90)
    $path.AddArc($width - $diameter, $height - $diameter, $diameter, $diameter, 0, 90)
    $path.AddArc(0, $height - $diameter, $diameter, $diameter, 90, 90)
    $path.CloseFigure()
    $Form.Region = New-Object System.Drawing.Region $path
}

function Move-WidgetToCorner {
    param($Form)
    $parent = [IntPtr]::Zero
    if ($Form.Tag -and $Form.Tag.ParentHandle) { $parent = [IntPtr]$Form.Tag.ParentHandle }
    if ($parent -ne [IntPtr]::Zero -and [DesktopWidgetNative.Host]::IsWindow($parent)) {
        [DesktopWidgetNative.Host]::PlaceInParent($Form.Handle, $parent, $Form.Width, $Form.Height)
        return
    }
    $area = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
    $x = $area.Right - $Form.Width - 24
    $y = $area.Bottom - $Form.Height - 24
    $Form.Location = New-Object System.Drawing.Point $x, $y
}

function Attach-WidgetToDesktop {
    param($Form)
    $hostHandle = [DesktopWidgetNative.Host]::FindDesktopHost()
    if ($hostHandle -eq [IntPtr]::Zero) { return $false }
    if ($Form.Tag -and $Form.Tag.ParentHandle -eq $hostHandle -and [DesktopWidgetNative.Host]::IsWindow($hostHandle)) {
        return $true
    }
    [void][DesktopWidgetNative.Host]::SetParent($Form.Handle, $hostHandle)
    $Form.Tag.ParentHandle = $hostHandle
    Move-WidgetToCorner $Form
    return $true
}

function New-WidgetButton {
    param([string]$Text, [int]$Left, [int]$Top, [int]$Width)
    $button = New-Object System.Windows.Forms.Button
    $button.Text = $Text
    $button.Left = $Left
    $button.Top = $Top
    $button.Width = $Width
    $button.Height = 40
    $button.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $button.FlatAppearance.BorderSize = 0
    $button.BackColor = [System.Drawing.Color]::FromArgb(31, 111, 235)
    $button.ForeColor = [System.Drawing.Color]::White
    $button.Font = New-Object System.Drawing.Font 'Segoe UI', 10
    $button.Cursor = [System.Windows.Forms.Cursors]::Hand
    return $button
}

function Submit-WidgetTicket {
    param(
        [string]$Summary,
        [string]$Description
    )
    $config = Import-WidgetConfig $script:WidgetConfigPath
    $paths = Get-WidgetStoragePaths $script:WidgetDataDirectory
    $summaryText = Normalize-TicketSummary $Summary
    $offline = $false
    if ($null -ne $script:WidgetBridge -and $script:WidgetBridge.Mode -eq 'Offline') { $offline = $true }
    $canApi = -not [string]::IsNullOrWhiteSpace($config.ApiBaseUrl) -and -not [string]::IsNullOrWhiteSpace($config.ServiceDeskId) -and -not [string]::IsNullOrWhiteSpace($config.RequestTypeId)
    if ($canApi) {
        if ($offline) {
            Add-OutboxTicket -Path $paths.OutboxPath -Summary $summaryText -Description $Description | Out-Null
            $script:WidgetBridge.OutboxDirty = $true
            return 'Сеть недоступна. Заявка сохранится и уйдёт, когда сетевой рабочий стол снова будет доступен.'
        }
        $result = Invoke-ServiceDeskRequest -ApiBaseUrl $config.ApiBaseUrl -ServiceDeskId $config.ServiceDeskId -RequestTypeId $config.RequestTypeId -Summary $summaryText -Description $Description
        if ($result.Ok) { return [string]$result.Message }
        Add-OutboxTicket -Path $paths.OutboxPath -Summary $summaryText -Description $Description | Out-Null
        $script:WidgetBridge.OutboxDirty = $true
        return "Заявка сохранится и уйдёт, когда сервис-деск ответит. $($result.Message)"
    }
    if (-not [string]::IsNullOrWhiteSpace($config.PortalUrl)) {
        $clip = "Тема: $summaryText"
        if (-not [string]::IsNullOrWhiteSpace($Description)) { $clip = "$clip`r`n`r`n$($Description.Trim())" }
        try { [System.Windows.Forms.Clipboard]::SetText($clip) } catch {}
        Start-Process $config.PortalUrl | Out-Null
        return 'Портал открыт в браузере. Текст заявки скопирован, его можно вставить в форму.'
    }
    return 'Адрес портала не задан. В config.json нужно указать widget.portalUrl или widget.apiBaseUrl.'
}

function Show-TicketDialog {
    $config = Import-WidgetConfig $script:WidgetConfigPath
    $dialog = New-Object System.Windows.Forms.Form
    $dialog.Text = 'Заявка в сервис-деск'
    $dialog.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
    $dialog.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
    $dialog.MaximizeBox = $false
    $dialog.MinimizeBox = $false
    $dialog.ClientSize = New-Object System.Drawing.Size 440, 390
    $dialog.Font = New-Object System.Drawing.Font 'Segoe UI', 10
    $dialog.TopMost = $true

    $topicLabel = New-Object System.Windows.Forms.Label
    $topicLabel.Text = 'Тема'
    $topicLabel.Left = 16
    $topicLabel.Top = 16
    $topicLabel.AutoSize = $true
    $topic = New-Object System.Windows.Forms.TextBox
    $topic.Left = 16
    $topic.Top = 40
    $topic.Width = 408

    $bodyLabel = New-Object System.Windows.Forms.Label
    $bodyLabel.Text = 'Что случилось'
    $bodyLabel.Left = 16
    $bodyLabel.Top = 74
    $bodyLabel.AutoSize = $true
    $body = New-Object System.Windows.Forms.TextBox
    $body.Left = 16
    $body.Top = 98
    $body.Width = 408
    $body.Height = 150
    $body.Multiline = $true
    $body.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical

    $send = New-WidgetButton -Text 'Отправить' -Left 16 -Top 264 -Width 140
    $portal = $null
    if (-not [string]::IsNullOrWhiteSpace($config.PortalUrl)) {
        $portal = New-WidgetButton -Text 'Открыть портал' -Left 168 -Top 264 -Width 160
        $portal.BackColor = [System.Drawing.Color]::FromArgb(36, 92, 138)
        $portalUrl = $config.PortalUrl
        $portal.Add_Click({ Start-Process $portalUrl | Out-Null }.GetNewClosure())
    }
    $resultLabel = New-Object System.Windows.Forms.Label
    $resultLabel.Left = 16
    $resultLabel.Top = 316
    $resultLabel.Width = 408
    $resultLabel.Height = 58
    $send.Add_Click({
        try {
            $resultLabel.Text = Submit-WidgetTicket -Summary $topic.Text -Description $body.Text
        } catch {
            $resultLabel.Text = $_.Exception.Message
        }
    })
    $dialog.Controls.AddRange(@($topicLabel, $topic, $bodyLabel, $body, $send, $resultLabel))
    if ($null -ne $portal) { [void]$dialog.Controls.Add($portal) }
    [void]$dialog.ShowDialog()
    $dialog.Dispose()
}

function Show-NewsDialog {
    $dialog = New-Object System.Windows.Forms.Form
    $dialog.Text = 'Новости'
    if ($script:WidgetBridge.FromCache) { $dialog.Text = 'Новости, сохранённая копия' }
    $dialog.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
    $dialog.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
    $dialog.MaximizeBox = $false
    $dialog.MinimizeBox = $false
    $dialog.ClientSize = New-Object System.Drawing.Size 460, 520
    $dialog.Font = New-Object System.Drawing.Font 'Segoe UI', 10
    $dialog.TopMost = $true

    $list = New-Object System.Windows.Forms.ListBox
    $list.Left = 16
    $list.Top = 16
    $list.Width = 428
    $list.Height = 180
    $list.IntegralHeight = $false
    $detail = New-Object System.Windows.Forms.TextBox
    $detail.Left = 16
    $detail.Top = 208
    $detail.Width = 428
    $detail.Height = 220
    $detail.Multiline = $true
    $detail.ReadOnly = $true
    $detail.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
    $open = New-WidgetButton -Text 'Открыть ссылку' -Left 16 -Top 448 -Width 160
    $open.Enabled = $false
    $close = New-WidgetButton -Text 'Закрыть' -Left 188 -Top 448 -Width 120
    $close.BackColor = [System.Drawing.Color]::FromArgb(36, 92, 138)
    $close.Add_Click({ $dialog.Close() })
    $hint = New-Object System.Windows.Forms.Label
    $hint.Left = 16
    $hint.Top = 492
    $hint.Width = 428
    $hint.Height = 20
    $hint.Text = [string]$script:WidgetBridge.FeedMessage

    $items = @()
    try { $items = Import-WidgetFeed $script:WidgetBridge.ItemsJson } catch { $items = @() }
    $paths = Get-WidgetStoragePaths $script:WidgetDataDirectory
    foreach ($item in $items) {
        if ($null -eq $item) { continue }
        [void]$list.Items.Add([pscustomobject]@{
            Caption = (Format-FeedCaption $item)
            Item = $item
        })
    }
    $list.DisplayMember = 'Caption'
    $list.Add_SelectedIndexChanged({
        $selected = $list.SelectedItem
        if ($null -eq $selected) { return }
        $feedItem = $selected.Item
        $detail.Text = [string]$feedItem.Body
        $open.Enabled = -not [string]::IsNullOrWhiteSpace([string]$feedItem.Url)
        $open.Tag = [string]$feedItem.Url
        Add-WidgetReadId -Path $paths.StatePath -Id $feedItem.Id
        $state = Read-WidgetState $paths.StatePath
        $script:WidgetBridge.UnreadCount = Get-WidgetUnreadCount -Items $items -ReadIds $state.ReadIds
    }.GetNewClosure())
    $open.Add_Click({
        if (-not [string]::IsNullOrWhiteSpace([string]$open.Tag)) { Start-Process ([string]$open.Tag) | Out-Null }
    }.GetNewClosure())
    if ($items.Count -eq 0 -and [string]::IsNullOrWhiteSpace($hint.Text)) {
        $hint.Text = 'Пока нет новостей.'
    }
    $dialog.Controls.AddRange(@($list, $detail, $open, $close, $hint))
    [void]$dialog.ShowDialog()
    $dialog.Dispose()
}

function Update-WidgetCard {
    param($Form)
    $bridge = $script:WidgetBridge
    if ($null -eq $bridge) { return }
    $Form.Tag.StatusLabel.Text = [string]$bridge.StatusText
    $count = 0
    try { $count = [int]$bridge.UnreadCount } catch { $count = 0 }
    if ($count -gt 0) { $Form.Tag.NewsButton.Text = "Новости ($count)" }
    else { $Form.Tag.NewsButton.Text = 'Новости' }
    if ($bridge.Mode -eq 'Offline') {
        $Form.Tag.StatusDot.BackColor = [System.Drawing.Color]::FromArgb(240, 180, 41)
    } else {
        $Form.Tag.StatusDot.BackColor = [System.Drawing.Color]::FromArgb(61, 220, 151)
    }
}

function Show-WidgetToasts {
    $bridge = $script:WidgetBridge
    if ($null -eq $bridge -or $null -eq $script:WidgetNotify) { return }
    $generation = 0
    try { $generation = [int]$bridge.FeedGeneration } catch { $generation = 0 }
    if ($generation -eq $script:WidgetShownGeneration) { return }
    $script:WidgetShownGeneration = $generation
    $items = @()
    try { $items = Import-WidgetFeed ([string]$bridge.FreshJson) } catch { return }
    $items = @($items | Where-Object { $null -ne $_ })
    if ($items.Count -eq 0) { return }
    $first = Format-FeedNotification $items[0]
    $text = $first.Text
    if ($items.Count -gt 1) { $text = "$text Ещё $($items.Count - 1)." }
    $script:WidgetNotify.BalloonTipTitle = $first.Title
    $script:WidgetNotify.BalloonTipText = $text
    $script:WidgetNotify.ShowBalloonTip(8000)
}

function New-DesktopWidgetForm {
    $config = Import-WidgetConfig $script:WidgetConfigPath
    $form = New-Object System.Windows.Forms.Form
    $form.Text = $config.Title
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
    $form.ShowInTaskbar = $false
    $form.TopMost = $false
    $form.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
    $form.ClientSize = New-Object System.Drawing.Size 320, 168
    $form.BackColor = [System.Drawing.Color]::FromArgb(18, 48, 82)
    $form.ForeColor = [System.Drawing.Color]::White
    $form.Font = New-Object System.Drawing.Font 'Segoe UI', 10
    Set-RoundedWidgetRegion $form 16

    $title = New-Object System.Windows.Forms.Label
    $title.Text = $config.Title
    $title.Left = 16
    $title.Top = 14
    $title.Width = 288
    $title.Height = 28
    $title.ForeColor = [System.Drawing.Color]::White
    $title.Font = New-Object System.Drawing.Font 'Segoe UI', 14, ([System.Drawing.FontStyle]::Bold)
    $title.AutoEllipsis = $true

    $dot = New-Object System.Windows.Forms.Panel
    $dot.Left = 18
    $dot.Top = 52
    $dot.Width = 10
    $dot.Height = 10
    $dot.BackColor = [System.Drawing.Color]::FromArgb(61, 220, 151)

    $status = New-Object System.Windows.Forms.Label
    $status.Text = 'Проверяю сеть'
    $status.Left = 34
    $status.Top = 46
    $status.Width = 270
    $status.Height = 36
    $status.ForeColor = [System.Drawing.Color]::FromArgb(208, 215, 226)

    $ticket = New-WidgetButton -Text 'Заявка' -Left 16 -Top 96 -Width 140
    $news = New-WidgetButton -Text 'Новости' -Left 164 -Top 96 -Width 140
    $news.BackColor = [System.Drawing.Color]::FromArgb(36, 92, 138)
    $ticket.Add_Click({ Show-TicketDialog })
    $news.Add_Click({ Show-NewsDialog })
    $form.Controls.AddRange(@($title, $dot, $status, $ticket, $news))

    $menu = New-Object System.Windows.Forms.ContextMenuStrip
    $ticketItem = $menu.Items.Add('Заявка')
    $newsItem = $menu.Items.Add('Новости')
    $exitItem = $menu.Items.Add('Выход')
    $ticketItem.Add_Click({ Show-TicketDialog })
    $newsItem.Add_Click({ Show-NewsDialog })
    $exitItem.Add_Click({
        $script:WidgetBridge.ExitRequested = $true
        $form.Close()
    }.GetNewClosure())
    $form.ContextMenuStrip = $menu

    $notify = New-Object System.Windows.Forms.NotifyIcon
    $notify.Icon = New-WidgetIcon
    $notify.Text = $config.Title
    $notify.Visible = $true
    $notify.ContextMenuStrip = $menu
    $notify.Add_DoubleClick({ Show-NewsDialog })
    $script:WidgetNotify = $notify

    $form.Tag = @{
        StatusLabel = $status
        StatusDot = $dot
        NewsButton = $news
        ParentHandle = [IntPtr]::Zero
        Ticks = 0
    }
    $form.Add_Shown({
        try { Move-WidgetToCorner $form } catch {}
        try { [void](Attach-WidgetToDesktop $form) } catch {}
        try { Update-WidgetCard $form } catch {}
    }.GetNewClosure())
    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 1000
    $timer.Add_Tick({
        try {
            Update-WidgetCard $form
            Show-WidgetToasts
            $form.Tag.Ticks = [int]$form.Tag.Ticks + 1
            if (([int]$form.Tag.Ticks % 5) -eq 0) {
                $parent = [IntPtr]$form.Tag.ParentHandle
                if ($parent -eq [IntPtr]::Zero -or -not [DesktopWidgetNative.Host]::IsWindow($parent)) {
                    try { [void](Attach-WidgetToDesktop $form) } catch {}
                }
            }
        } catch {}
    }.GetNewClosure())
    $timer.Start()
    $form.Add_FormClosed({
        $timer.Stop()
        $timer.Dispose()
        if ($null -ne $script:WidgetNotify) {
            $script:WidgetNotify.Visible = $false
            $script:WidgetNotify.Dispose()
            $script:WidgetNotify = $null
        }
    }.GetNewClosure())
    return $form
}

function Start-DesktopWidgetHost {
    param(
        $Bridge,
        [string]$ConfigPath,
        [string]$DataDirectory
    )
    if (-not (Test-IsWindowsPlatform)) { return }
    Initialize-WidgetUi
    $script:WidgetBridge = $Bridge
    $script:WidgetConfigPath = $ConfigPath
    $script:WidgetDataDirectory = $DataDirectory
    if (-not $script:WidgetShownGeneration) { $script:WidgetShownGeneration = 0 }
    while (-not $Bridge.ExitRequested) {
        $form = New-DesktopWidgetForm
        [System.Windows.Forms.Application]::Run($form)
        if ($Bridge.ExitRequested) { break }
        Start-Sleep -Milliseconds 700
    }
}
