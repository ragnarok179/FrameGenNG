[CmdletBinding()]
param(
    [ValidateSet('Gui', 'Install', 'Repair', 'Uninstall', 'Status', 'CheckUpdate')]
    [string]$Action = 'Gui',
    [string]$GameRoot,
    [string]$LauncherIni,
    [ValidateSet('Auto', 'LegacyRTX', 'NativeRTX')]
    [string]$Profile = 'Auto'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'FrameGenNG.Core.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'FrameGenNG.Update.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'FrameGenNG.Diagnostics.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'FrameGenNG.Ui.psm1') -Force

function Format-StatusText {
    param($Status)
    if (-not [bool]$Status.installed) {
        return "Not installed`r`nThe game has not been modified by this package."
    }
    if ([bool]$Status.healthy) {
        return "Installed and healthy`r`nVersion $($Status.version) · $($Status.profile) · $($Status.gpu)"
    }
    if ([bool]$Status.gameUpdateDetected) {
        return "BeamNG update detected`r`nRepair FrameGenNG before starting the game."
    }
    if ([bool]$Status.stateRecoveredFromBackup) {
        return "Recovery state loaded`r`nRepair FrameGenNG to rebuild the primary installation state."
    }
    $broken = @($Status.checks | Where-Object { -not $_.matchesInstalled }).Count
    return "Repair recommended`r`n$broken item(s) missing or modified."
}

function Invoke-CommandLineAction {
    switch ($Action) {
        'Install' {
            $installationState = Install-FrameGenNG -GameRoot $GameRoot -LauncherIni $LauncherIni -Profile $Profile
            Write-Host "FrameGenNG $($installationState.version) installed with profile $($installationState.profile)." -ForegroundColor Green
        }
        'Repair' {
            $installationState = Repair-FrameGenNG -GameRoot $GameRoot -LauncherIni $LauncherIni
            Write-Host "FrameGenNG $($installationState.version) repaired successfully." -ForegroundColor Green
        }
        'Uninstall' {
            $uninstallSummary = Uninstall-FrameGenNG -GameRoot $GameRoot -LauncherIni $LauncherIni
            Write-Host 'FrameGenNG uninstalled. The original files were restored.' -ForegroundColor Green
            Write-Host "Backup preserved: $($uninstallSummary.backupKept)"
        }
        'Status' {
            Get-FrameGenNGStatus -GameRoot $GameRoot -LauncherIni $LauncherIni | ConvertTo-Json -Depth 10
        }
        'CheckUpdate' {
            $currentVersion = Get-FrameGenNGVersion
            Get-FrameGenNGUpdateInfo -CurrentVersion $currentVersion -IncludePrerelease:$false | ConvertTo-Json -Depth 10
        }
    }
}

if ($Action -ne 'Gui') {
    try {
        Invoke-CommandLineAction
        exit 0
    } catch {
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$colors = @{
    Window = [System.Drawing.SystemColors]::Window
    Panel = [System.Drawing.SystemColors]::Window
    PanelRaised = [System.Drawing.SystemColors]::Control
    Border = [System.Drawing.SystemColors]::ActiveBorder
    Text = [System.Drawing.SystemColors]::WindowText
    Muted = [System.Drawing.SystemColors]::GrayText
    Accent = [System.Drawing.Color]::FromArgb(0, 102, 153)
    AccentHover = [System.Drawing.Color]::FromArgb(0, 84, 126)
    Success = [System.Drawing.Color]::FromArgb(0, 128, 0)
    Warning = [System.Drawing.Color]::FromArgb(191, 112, 0)
    Danger = [System.Drawing.Color]::FromArgb(192, 0, 0)
}

$initialLayout = Get-FrameGenNGManagerLayout -StatusHeight 38

$form = New-Object System.Windows.Forms.Form
$form.Text = "FrameGenNG v$(Get-FrameGenNGVersion)"
$form.StartPosition = 'CenterScreen'
$form.ClientSize = New-Object System.Drawing.Size(470, $initialLayout.FormHeight)
$form.BackColor = $colors.Window
$form.ForeColor = $colors.Text
$form.Font = New-Object System.Drawing.Font('Segoe UI', 9)
$form.MaximizeBox = $false
$form.MinimizeBox = $false
$form.ShowIcon = $false
$form.FormBorderStyle = 'FixedDialog'

$statusDot = New-Object System.Windows.Forms.Label
$statusDot.Visible = $false

$statusText = New-Object System.Windows.Forms.Label
$statusText.Text = 'Checking…'
$statusText.Location = New-Object System.Drawing.Point(31, $initialLayout.StatusTop)
$statusText.Size = New-Object System.Drawing.Size(408, $initialLayout.StatusHeight)
$statusText.ForeColor = $colors.Text
$form.Controls.Add($statusText)

$gamePathText = New-Object System.Windows.Forms.Label
$gamePathText.Visible = $false

function New-ActionButton {
    param([string]$Text, [int]$X, [int]$Width, [System.Drawing.Color]$BackColor)
    return New-FrameGenNGButton -Text $Text -X $X -Y $initialLayout.ActionTop -Width $Width -Height 30 -Colors $colors -Style Secondary
}

$installButton = New-ActionButton -Text 'Install' -X 31 -Width 104 -BackColor $colors.Accent
$repairButton = New-ActionButton -Text 'Repair' -X 143 -Width 104 -BackColor $colors.PanelRaised
$uninstallButton = New-ActionButton -Text 'Uninstall' -X 255 -Width 104 -BackColor $colors.PanelRaised
$form.Controls.AddRange(@($installButton, $repairButton, $uninstallButton))

$updateButton = New-FrameGenNGButton -Text 'Check for updates' -X 31 -Y $initialLayout.UpdateTop -Width 328 -Height 30 -Colors $colors
$form.Controls.Add($updateButton)

$restorePointsButton = New-FrameGenNGButton -Text 'Restore points…' -X 31 -Y $initialLayout.SecondaryActionTop -Width 130 -Height 28 -Colors $colors
$diagnosticButton = New-FrameGenNGButton -Text 'Diagnostics…' -X 169 -Y $initialLayout.SecondaryActionTop -Width 112 -Height 28 -Colors $colors
$detailsButton = New-FrameGenNGButton -Text 'Details ▸' -X 289 -Y $initialLayout.SecondaryActionTop -Width 70 -Height 28 -Colors $colors
$form.Controls.AddRange(@($restorePointsButton, $diagnosticButton, $detailsButton))

$footer = New-Object System.Windows.Forms.Panel
$footer.Location = New-Object System.Drawing.Point(0, $initialLayout.FooterTop)
$footer.Size = New-Object System.Drawing.Size(470, 56)
$footer.BackColor = [System.Drawing.SystemColors]::Control
$form.Controls.Add($footer)

$footerLine = New-Object System.Windows.Forms.Panel
$footerLine.Location = New-Object System.Drawing.Point(0, 0)
$footerLine.Size = New-Object System.Drawing.Size(470, 1)
$footerLine.BackColor = [System.Drawing.SystemColors]::ActiveBorder
$footer.Controls.Add($footerLine)

$closeButton = New-FrameGenNGButton -Text 'Close' -X 363 -Y 14 -Width 82 -Height 28 -Colors $colors -DialogResult Cancel
$footer.Controls.Add($closeButton)
$form.CancelButton = $closeButton

$gamePathBox = New-Object System.Windows.Forms.TextBox
$gamePathBox.Visible = $false
$userPathBox = New-Object System.Windows.Forms.TextBox
$userPathBox.Visible = $false

$logBox = New-Object System.Windows.Forms.TextBox
$logBox.Location = New-Object System.Drawing.Point(31, $initialLayout.LogTop)
$logBox.Size = New-Object System.Drawing.Size(408, 130)
$logBox.Multiline = $true
$logBox.ReadOnly = $true
$logBox.Visible = $false
$logBox.ScrollBars = 'Vertical'
$logBox.BorderStyle = 'FixedSingle'
$logBox.BackColor = [System.Drawing.SystemColors]::Window
$logBox.ForeColor = $colors.Text
$logBox.Font = New-Object System.Drawing.Font('Consolas', 8.5)
$form.Controls.Add($logBox)

$script:resolvedGameRoot = $null
$script:resolvedUserRoot = $null
$script:updateInfo = $null
$script:updateJob = $null
$script:updateCheckWasManual = $false
$script:detailsExpanded = $false

function Update-MainLayout {
    $preferredStatusHeight = $statusText.GetPreferredSize(
        [System.Drawing.Size]::new($statusText.Width, 0)
    ).Height
    $layout = Get-FrameGenNGManagerLayout -StatusHeight $preferredStatusHeight -Expanded $script:detailsExpanded

    $form.SuspendLayout()
    try {
        $statusText.Height = $layout.StatusHeight
        foreach ($button in @($installButton, $repairButton, $uninstallButton)) {
            $button.Top = $layout.ActionTop
        }
        $updateButton.Top = $layout.UpdateTop
        foreach ($button in @($restorePointsButton, $diagnosticButton, $detailsButton)) {
            $button.Top = $layout.SecondaryActionTop
        }
        $logBox.Top = $layout.LogTop
        $footer.Top = $layout.FooterTop
        $form.ClientSize = New-Object System.Drawing.Size(470, $layout.FormHeight)
    } finally {
        $form.ResumeLayout($true)
    }
}

function Set-DetailsExpanded {
    param([Parameter(Mandatory)][bool]$Expanded)

    $script:detailsExpanded = $Expanded
    $logBox.Visible = $Expanded
    $detailsButton.Text = if ($Expanded) { 'Details ▾' } else { 'Details ▸' }
    Update-MainLayout
}

function Set-BusyState {
    param([bool]$Busy)
    foreach ($button in @($installButton, $repairButton, $uninstallButton, $diagnosticButton, $updateButton, $restorePointsButton)) {
        $button.Enabled = -not $Busy
    }
    if (-not $Busy -and $null -ne $script:updateJob) { $updateButton.Enabled = $false }
    $form.UseWaitCursor = $Busy
    [System.Windows.Forms.Application]::DoEvents()
}

function Write-ManagerLog {
    param([string]$Message)
    $entry = "$((Get-Date).ToString('HH:mm:ss'))  $Message"
    if ([string]::IsNullOrWhiteSpace($logBox.Text)) {
        $logBox.Text = $entry
    } else {
        $logBox.AppendText("`r`n$entry")
    }
    $logBox.SelectionStart = $logBox.TextLength
    $logBox.ScrollToCaret()
    if (-not [string]::IsNullOrWhiteSpace([string]$script:resolvedUserRoot)) {
        Write-FrameGenNGDiagnosticLog -UserRoot $script:resolvedUserRoot -Message $Message | Out-Null
    }
}

function Show-DiagnosticsDialog {
    $dialog = New-FrameGenNGDialog -Title 'FrameGenNG Diagnostics' -Width 580 -Height 390 -Colors $colors

    $heading = New-Object System.Windows.Forms.Label
    $heading.Text = 'Installation diagnostics'
    $heading.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 13)
    $heading.Location = New-Object System.Drawing.Point(16, 14)
    $heading.AutoSize = $true
    $dialog.Controls.Add($heading)

    $advancedCheck = New-Object System.Windows.Forms.CheckBox
    $advancedCheck.Text = 'Enable advanced diagnostic logging'
    $advancedCheck.Location = New-Object System.Drawing.Point(16, 46)
    $advancedCheck.Size = New-Object System.Drawing.Size(330, 28)
    $advancedCheck.ForeColor = $colors.Text
    $advancedCheck.Checked = [bool](Get-FrameGenNGManagerSettings -UserRoot $script:resolvedUserRoot).advancedDiagnostics
    $dialog.Controls.Add($advancedCheck)

    $advancedInfo = New-Object System.Windows.Forms.Label
    $advancedInfo.Text = 'When enabled, the manager keeps detailed action and error logs. It does not add per-frame game logging or affect performance while driving.'
    $advancedInfo.Location = New-Object System.Drawing.Point(35, 73)
    $advancedInfo.Size = New-Object System.Drawing.Size(525, 34)
    $advancedInfo.ForeColor = $colors.Muted
    $dialog.Controls.Add($advancedInfo)

    $resultBox = New-Object System.Windows.Forms.TextBox
    $resultBox.Location = New-Object System.Drawing.Point(16, 112)
    $resultBox.Size = New-Object System.Drawing.Size(548, 210)
    $resultBox.Anchor = 'Top,Bottom,Left,Right'
    $resultBox.Multiline = $true
    $resultBox.ReadOnly = $true
    $resultBox.ScrollBars = 'Vertical'
    $resultBox.BackColor = [System.Drawing.SystemColors]::Window
    $resultBox.ForeColor = $colors.Text
    $resultBox.BorderStyle = 'FixedSingle'
    $resultBox.Font = New-Object System.Drawing.Font('Consolas', 9.5)
    $dialog.Controls.Add($resultBox)

    $scanButton = New-FrameGenNGButton -Text 'Run scan' -X 16 -Y 338 -Width 110 -Height 34 -Colors $colors -Anchor 'Bottom,Left'
    $exportButton = New-FrameGenNGButton -Text 'Export diagnostic bundle' -X 240 -Y 338 -Width 180 -Height 34 -Colors $colors -Style Accent -Anchor 'Bottom,Right'
    $closeButton = New-FrameGenNGButton -Text 'Close' -X 430 -Y 338 -Width 134 -Height 34 -Colors $colors -Anchor 'Bottom,Right' -DialogResult Cancel
    $dialog.CancelButton = $closeButton
    $dialog.Controls.AddRange(@($scanButton, $exportButton, $closeButton))

    $runScan = {
        try {
            $status = Get-FrameGenNGStatus -GameRoot $script:resolvedGameRoot -LauncherIni $LauncherIni
            $summary = Get-FrameGenNGDiagnosticSummary -Status $status
            $lines = [System.Collections.Generic.List[string]]::new()
            $lines.Add("Status: $($summary.health)")
            $lines.Add("FrameGenNG: v$($summary.version)")
            if (-not [string]::IsNullOrWhiteSpace([string]$summary.profile)) { $lines.Add("Profile: $($summary.profile)") }
            $lines.Add("Advanced logging: $(if ($advancedCheck.Checked) { 'Enabled' } else { 'Disabled' })")
            $lines.Add('')
            if (@($summary.issues).Count -eq 0) {
                $lines.Add('No issue was detected by the standard integrity checks.')
            } else {
                $lines.Add('Findings:')
                foreach ($issue in @($summary.issues)) { $lines.Add("- $issue") }
            }
            $resultBox.Lines = $lines.ToArray()
            Write-ManagerLog -Message "Diagnostics scan: $($summary.health)."
        } catch {
            $resultBox.Text = "Diagnostic scan failed.`r`n`r`n$($_.Exception.Message)"
            Write-ManagerLog -Message "Diagnostics error: $($_.Exception.Message)"
        }
    }

    $advancedCheck.Add_CheckedChanged({
        try {
            Set-FrameGenNGAdvancedDiagnostics -UserRoot $script:resolvedUserRoot -Enabled ([bool]$advancedCheck.Checked) | Out-Null
            $state = if ($advancedCheck.Checked) { 'enabled' } else { 'disabled' }
            Write-FrameGenNGDiagnosticLog -UserRoot $script:resolvedUserRoot -Message "Advanced diagnostic logging $state by the user." -Force | Out-Null
            Write-ManagerLog -Message "Advanced diagnostic logging $state."
            & $runScan
        } catch {
            [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Unable to change diagnostic mode', 'OK', 'Error') | Out-Null
        }
    })
    $scanButton.Add_Click({ & $runScan })
    $exportButton.Add_Click({
        $answer = [System.Windows.Forms.MessageBox]::Show(
            'The bundle can contain local folder paths, GPU information, installation state, and recent BeamNG or FrameGenNG log excerpts. Review it before sharing. Continue?',
            'Export diagnostic bundle', 'YesNo', 'Warning')
        if ($answer -ne 'Yes') { return }
        try {
            $exportButton.Enabled = $false
            $exportButton.Text = 'Exporting…'
            [System.Windows.Forms.Application]::DoEvents()
            $status = Get-FrameGenNGStatus -GameRoot $script:resolvedGameRoot -LauncherIni $LauncherIni
            $bundle = Export-FrameGenNGDiagnosticBundle -PackageRoot (Split-Path -Parent $PSScriptRoot) -GameRoot $script:resolvedGameRoot -UserRoot $script:resolvedUserRoot -Status $status
            Write-ManagerLog -Message "Diagnostic bundle created: $($bundle.path)"
            [System.Windows.Forms.MessageBox]::Show("Diagnostic bundle created.`r`n`r`n$($bundle.path)", 'Export complete', 'OK', 'Information') | Out-Null
        } catch {
            Write-ManagerLog -Message "Diagnostic export failed: $($_.Exception.Message)"
            [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Diagnostic export failed', 'OK', 'Error') | Out-Null
        } finally {
            $exportButton.Enabled = $true
            $exportButton.Text = 'Export diagnostic bundle'
        }
    })

    & $runScan
    [void]$dialog.ShowDialog($form)
}

function Show-RestorePointsDialog {
    $dialog = New-FrameGenNGDialog -Title 'FrameGenNG Restore Points' -Width 620 -Height 350 -Colors $colors

    $intro = New-Object System.Windows.Forms.Label
    $intro.Text = 'Automatic points are created before install, repair, update, uninstall, and restore. The five newest automatic points are kept; manual points are kept until you delete them.'
    $intro.Location = New-Object System.Drawing.Point(16, 12)
    $intro.Size = New-Object System.Drawing.Size(588, 36)
    $intro.ForeColor = $colors.Muted
    $dialog.Controls.Add($intro)

    $list = New-Object System.Windows.Forms.ListView
    $list.Location = New-Object System.Drawing.Point(16, 54)
    $list.Size = New-Object System.Drawing.Size(588, 225)
    $list.Anchor = 'Top,Bottom,Left,Right'
    $list.View = 'Details'
    $list.FullRowSelect = $true
    $list.MultiSelect = $false
    $list.HideSelection = $false
    $list.BackColor = $colors.Panel
    $list.ForeColor = $colors.Text
    $list.BorderStyle = 'FixedSingle'
    [void]$list.Columns.Add('Created', 120)
    [void]$list.Columns.Add('Restore point', 185)
    [void]$list.Columns.Add('Version', 75)
    [void]$list.Columns.Add('Type', 78)
    [void]$list.Columns.Add('Size', 80)
    $dialog.Controls.Add($list)

    $createButton = New-FrameGenNGButton -Text 'Create manual point' -X 16 -Y 295 -Width 150 -Height 34 -Colors $colors -Anchor 'Bottom,Left'
    $restoreButton = New-FrameGenNGButton -Text 'Restore selected' -X 302 -Y 295 -Width 125 -Height 34 -Colors $colors -Style Accent -Anchor 'Bottom,Right'
    $deleteButton = New-FrameGenNGButton -Text 'Delete' -X 435 -Y 295 -Width 75 -Height 34 -Colors $colors -Style Danger -Anchor 'Bottom,Right'
    $closeButton = New-FrameGenNGButton -Text 'Close' -X 518 -Y 295 -Width 86 -Height 34 -Colors $colors -Anchor 'Bottom,Right' -DialogResult Cancel
    $dialog.CancelButton = $closeButton
    $dialog.Controls.AddRange(@($createButton, $restoreButton, $deleteButton, $closeButton))

    $refreshList = {
        $list.Items.Clear()
        foreach ($point in @(Get-FrameGenNGRestorePoints -UserRoot $script:resolvedUserRoot)) {
            $item = New-Object System.Windows.Forms.ListViewItem(([datetime]$point.createdAt).ToLocalTime().ToString('yyyy-MM-dd HH:mm'))
            [void]$item.SubItems.Add([string]$point.label)
            [void]$item.SubItems.Add(('v' + [string]$point.version))
            $typeText = if ([string]$point.kind -eq 'manual') { 'Manual' } else { 'Automatic' }
            [void]$item.SubItems.Add($typeText)
            [void]$item.SubItems.Add(('{0:N1} MB' -f ([long]$point.sizeBytes / 1MB)))
            $item.Tag = $point
            [void]$list.Items.Add($item)
        }
        $hasSelection = $list.SelectedItems.Count -eq 1
        $restoreButton.Enabled = $hasSelection
        $deleteButton.Enabled = $hasSelection
    }
    $list.Add_SelectedIndexChanged({
        $hasSelection = $list.SelectedItems.Count -eq 1
        $restoreButton.Enabled = $hasSelection
        $deleteButton.Enabled = $hasSelection
    })
    $createButton.Add_Click({
        try {
            $createButton.Enabled = $false
            New-FrameGenNGRestorePoint -UserRoot $script:resolvedUserRoot -Reason 'manual' -GameRoot $script:resolvedGameRoot -LauncherIni $LauncherIni | Out-Null
            Write-ManagerLog -Message 'Manual restore point created.'
            & $refreshList
        } catch {
            [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Unable to create restore point', 'OK', 'Error') | Out-Null
        } finally { $createButton.Enabled = $true }
    })
    $deleteButton.Add_Click({
        if ($list.SelectedItems.Count -ne 1) { return }
        $point = $list.SelectedItems[0].Tag
        $answer = [System.Windows.Forms.MessageBox]::Show("Delete '$($point.label)' permanently?", 'Delete restore point', 'YesNo', 'Warning')
        if ($answer -ne 'Yes') { return }
        try {
            Remove-FrameGenNGRestorePoint -UserRoot $script:resolvedUserRoot -Id ([string]$point.id)
            Write-ManagerLog -Message "Deleted restore point: $($point.label)."
            & $refreshList
        } catch {
            [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Unable to delete restore point', 'OK', 'Error') | Out-Null
        }
    })
    $restoreButton.Add_Click({
        if ($list.SelectedItems.Count -ne 1) { return }
        $point = $list.SelectedItems[0].Tag
        $answer = [System.Windows.Forms.MessageBox]::Show(
            "Restore FrameGenNG v$($point.version) from '$($point.label)'?`r`n`r`nThe current state will be saved automatically before anything changes.",
            'Restore FrameGenNG', 'YesNo', 'Question')
        if ($answer -ne 'Yes') { return }
        try {
            Start-FrameGenNGRestore -RestorePoint $point -PackageRoot (Split-Path -Parent $PSScriptRoot) -GameRoot $script:resolvedGameRoot -UserRoot $script:resolvedUserRoot -LauncherIni $LauncherIni -ManagerProcessId $PID | Out-Null
            Write-ManagerLog -Message "Restore prepared for v$($point.version). Closing the manager…"
            $dialog.Close()
            $form.Close()
        } catch {
            [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Unable to start restore', 'OK', 'Error') | Out-Null
        }
    })

    & $refreshList
    [void]$dialog.ShowDialog($form)
}

$updateTimer = New-Object System.Windows.Forms.Timer
$updateTimer.Interval = 350

function Complete-UpdateCheck {
    $updateTimer.Stop()
    try {
        $raw = (Receive-Job -Job $script:updateJob -ErrorAction Stop | Out-String).Trim()
        $updateCheckResult = $raw | ConvertFrom-Json
        if (-not [bool]$updateCheckResult.success) { throw [string]$updateCheckResult.error }
        $script:updateInfo = $updateCheckResult.data
        if ([bool]$script:updateInfo.UpdateAvailable) {
            $updateButton.Text = "Update to v$($script:updateInfo.LatestVersion)"
            Write-ManagerLog -Message "Update available: v$($script:updateInfo.LatestVersion)."
        } else {
            $updateButton.Text = 'Up to date - check again'
            Write-ManagerLog -Message 'Update check: FrameGenNG is up to date.'
            if ($script:updateCheckWasManual) {
                [System.Windows.Forms.MessageBox]::Show('You already have the latest compatible FrameGenNG release.', 'FrameGenNG is up to date', 'OK', 'Information') | Out-Null
            }
        }
    } catch {
        $script:updateInfo = $null
        $updateButton.Text = 'Check for updates'
        Write-ManagerLog -Message "Update check unavailable: $($_.Exception.Message)"
        if ($script:updateCheckWasManual) {
            [System.Windows.Forms.MessageBox]::Show("FrameGenNG could not check GitHub Releases.`r`n`r`n$($_.Exception.Message)", 'Update check unavailable', 'OK', 'Warning') | Out-Null
        }
    } finally {
        if ($null -ne $script:updateJob) {
            Remove-Job -Job $script:updateJob -Force -ErrorAction SilentlyContinue
            $script:updateJob = $null
        }
        $updateButton.Enabled = $true
        $script:updateCheckWasManual = $false
    }
}

function Start-UpdateCheck {
    param([bool]$Manual = $false)
    if ($null -ne $script:updateJob) { return }
    $script:updateCheckWasManual = $Manual
    $updateButton.Text = 'Checking for updates…'
    $updateButton.Enabled = $false
    $currentVersion = Get-FrameGenNGVersion
    $includePrerelease = $false
    $modulePath = Join-Path $PSScriptRoot 'FrameGenNG.Update.psm1'
    $script:updateJob = Start-Job -ScriptBlock {
        param($ModulePath, $Version, $Prerelease)
        try {
            Import-Module $ModulePath -Force
            $updateInfo = Get-FrameGenNGUpdateInfo -CurrentVersion $Version -IncludePrerelease ([bool]$Prerelease)
            [pscustomobject]@{ success = $true; data = $updateInfo; error = $null } | ConvertTo-Json -Depth 12 -Compress
        } catch {
            [pscustomobject]@{ success = $false; data = $null; error = $_.Exception.Message } | ConvertTo-Json -Depth 4 -Compress
        }
    } -ArgumentList $modulePath, $currentVersion, $includePrerelease
    $updateTimer.Start()
}

$updateTimer.Add_Tick({
    if ($null -ne $script:updateJob -and $script:updateJob.State -in @('Completed', 'Failed', 'Stopped')) {
        Complete-UpdateCheck
    }
})

function Refresh-ManagerStatus {
    try {
        $script:resolvedGameRoot = Resolve-BeamNGGameRoot -GameRoot $GameRoot
        $script:resolvedUserRoot = Resolve-BeamNGUserRoot -LauncherIni $LauncherIni
        $gamePathBox.Text = $script:resolvedGameRoot
        $userPathBox.Text = $script:resolvedUserRoot
        $gamePathText.Text = "BeamNG installation: $($script:resolvedGameRoot)"
        $status = Get-FrameGenNGStatus -GameRoot $script:resolvedGameRoot -LauncherIni $LauncherIni
        $statusText.Text = Format-StatusText -Status $status
        Update-MainLayout
        if (-not [bool]$status.installed) {
            $statusDot.ForeColor = $colors.Muted
            $installButton.Enabled = $true
            $repairButton.Enabled = $false
            $uninstallButton.Enabled = $false
        } elseif ([bool]$status.healthy) {
            $statusDot.ForeColor = $colors.Success
            $installButton.Enabled = $false
            $repairButton.Enabled = $true
            $uninstallButton.Enabled = $true
        } else {
            $statusDot.ForeColor = $colors.Warning
            $installButton.Enabled = $false
            $repairButton.Enabled = $true
            $uninstallButton.Enabled = $true
        }
        return $status
    } catch {
        $statusText.Text = "Invalid configuration`r`n$($_.Exception.Message)"
        Update-MainLayout
        $statusDot.ForeColor = $colors.Danger
        $gamePathBox.Text = if ($null -ne $GameRoot) { $GameRoot } else { 'Package is not in the BeamNG root folder' }
        $userPathBox.Text = 'Unavailable'
        $gamePathText.Text = 'BeamNG installation could not be detected.'
        $installButton.Enabled = $false
        $repairButton.Enabled = $false
        $uninstallButton.Enabled = $false
        Write-ManagerLog -Message $_.Exception.Message
        return $null
    }
}

$installButton.Add_Click({
    try {
        Set-BusyState -Busy $true
        $detected = Get-NvidiaRtxProfile -Profile $Profile
        $answer = [System.Windows.Forms.MessageBox]::Show(
            "GPU: $($detected.Gpu)`r`nProfile: $($detected.Profile)`r`n`r`nFrameGenNG will verify its package, back up user overrides, and install the graphics layer. Installation stops if another graphics proxy is present. Continue?",
            'Install FrameGenNG', 'YesNo', 'Question')
        if ($answer -ne 'Yes') { return }
        Write-ManagerLog -Message 'Installing…'
        $installationState = Install-FrameGenNG -GameRoot $script:resolvedGameRoot -LauncherIni $LauncherIni -Profile $Profile
        Write-ManagerLog -Message "Installation complete: $($installationState.profile)."
        [System.Windows.Forms.MessageBox]::Show('FrameGenNG is installed. Start BeamNG in DirectX 12 and enable DLSS.', 'Installation complete', 'OK', 'Information') | Out-Null
    } catch {
        Write-ManagerLog -Message "Error: $($_.Exception.Message)"
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Installation failed', 'OK', 'Error') | Out-Null
    } finally {
        Set-BusyState -Busy $false
        Refresh-ManagerStatus | Out-Null
    }
})

$repairButton.Add_Click({
    try {
        $answer = [System.Windows.Forms.MessageBox]::Show('Repair preserves your Frame Generation settings, safely removes the current integration, then rebuilds it from the current BeamNG files. Continue?', 'Repair FrameGenNG', 'YesNo', 'Question')
        if ($answer -ne 'Yes') { return }
        Set-BusyState -Busy $true
        Write-ManagerLog -Message 'Repairing…'
        Repair-FrameGenNG -GameRoot $script:resolvedGameRoot -LauncherIni $LauncherIni | Out-Null
        Write-ManagerLog -Message 'Repair complete.'
        [System.Windows.Forms.MessageBox]::Show('FrameGenNG has been rebuilt for the current BeamNG installation. Your Frame Generation settings were preserved.', 'Repair complete', 'OK', 'Information') | Out-Null
    } catch {
        Write-ManagerLog -Message "Error: $($_.Exception.Message)"
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Repair failed', 'OK', 'Error') | Out-Null
    } finally {
        Set-BusyState -Busy $false
        Refresh-ManagerStatus | Out-Null
    }
})

$uninstallButton.Add_Click({
    try {
        $answer = [System.Windows.Forms.MessageBox]::Show('The backed-up original files will be restored. Backups will be preserved. Uninstall FrameGenNG?', 'Uninstall FrameGenNG', 'YesNo', 'Warning')
        if ($answer -ne 'Yes') { return }
        Set-BusyState -Busy $true
        Write-ManagerLog -Message 'Restoring original files…'
        $uninstallSummary = Uninstall-FrameGenNG -GameRoot $script:resolvedGameRoot -LauncherIni $LauncherIni
        Write-ManagerLog -Message "Uninstall complete. Backup: $($uninstallSummary.backupKept)"
        $message = if ([bool]$uninstallSummary.gameUpdateDetected) { 'FrameGenNG has been removed. Files replaced by a BeamNG update were preserved, and recovery copies were kept.' } else { 'FrameGenNG has been uninstalled and the original files were restored.' }
        [System.Windows.Forms.MessageBox]::Show($message, 'Uninstall complete', 'OK', 'Information') | Out-Null
    } catch {
        Write-ManagerLog -Message "Error: $($_.Exception.Message)"
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Uninstall failed', 'OK', 'Error') | Out-Null
    } finally {
        Set-BusyState -Busy $false
        Refresh-ManagerStatus | Out-Null
    }
})

$diagnosticButton.Add_Click({
    try {
        if ($null -eq $script:resolvedGameRoot -or $null -eq $script:resolvedUserRoot) { Refresh-ManagerStatus | Out-Null }
        Show-DiagnosticsDialog
    } catch {
        Write-ManagerLog -Message "Diagnostics error: $($_.Exception.Message)"
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Diagnostics unavailable', 'OK', 'Error') | Out-Null
    }
})

$restorePointsButton.Add_Click({
    try {
        if ($null -eq $script:resolvedGameRoot -or $null -eq $script:resolvedUserRoot) {
            Refresh-ManagerStatus | Out-Null
        }
        Show-RestorePointsDialog
    } catch {
        Write-ManagerLog -Message "Restore-points error: $($_.Exception.Message)"
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Restore points unavailable', 'OK', 'Error') | Out-Null
    }
})

$detailsButton.Add_Click({ Set-DetailsExpanded -Expanded (-not $script:detailsExpanded) })

$updateButton.Add_Click({
    if ($null -eq $script:updateInfo -or -not [bool]$script:updateInfo.UpdateAvailable) {
        Start-UpdateCheck -Manual $true
        return
    }
    $answer = [System.Windows.Forms.MessageBox]::Show(
        "FrameGenNG v$($script:updateInfo.LatestVersion) is available.`r`n`r`nThe manager will download and verify the official release, preserve your Frame Generation settings, and restart after the update.`r`n`r`nContinue?",
        'Update FrameGenNG', 'YesNo', 'Question')
    if ($answer -ne 'Yes') { return }
    $launched = $false
    try {
        Set-BusyState -Busy $true
        $updateButton.Text = 'Downloading and verifying…'
        Write-ManagerLog -Message "Downloading FrameGenNG v$($script:updateInfo.LatestVersion)…"
        [System.Windows.Forms.Application]::DoEvents()
        if ($null -eq $script:resolvedGameRoot -or $null -eq $script:resolvedUserRoot) {
            Refresh-ManagerStatus | Out-Null
        }
        Start-FrameGenNGUpdate -UpdateInfo $script:updateInfo -PackageRoot (Split-Path -Parent $PSScriptRoot) -GameRoot $script:resolvedGameRoot -UserRoot $script:resolvedUserRoot -LauncherIni $LauncherIni -ManagerProcessId $PID | Out-Null
        $launched = $true
        Write-ManagerLog -Message 'The verified updater is ready. Closing the manager…'
        $form.Close()
    } catch {
        Write-ManagerLog -Message "Update failed before installation: $($_.Exception.Message)"
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Unable to start the update', 'OK', 'Error') | Out-Null
    } finally {
        if (-not $launched) {
            Set-BusyState -Busy $false
            if ($null -ne $script:updateInfo -and [bool]$script:updateInfo.UpdateAvailable) {
                $updateButton.Text = "Update to v$($script:updateInfo.LatestVersion)"
            }
        }
    }
})

$form.Add_Shown({
    Write-ManagerLog -Message 'Manager ready.'
    Refresh-ManagerStatus | Out-Null
    Start-UpdateCheck -Manual $false
})
$form.Add_FormClosed({
    $updateTimer.Stop()
    if ($null -ne $script:updateJob) {
        Stop-Job -Job $script:updateJob -ErrorAction SilentlyContinue
        Remove-Job -Job $script:updateJob -Force -ErrorAction SilentlyContinue
    }
})
[void]$form.ShowDialog()

