[CmdletBinding()]
param(
    [ValidateSet('Gui', 'Install', 'Repair', 'Uninstall', 'Status')]
    [string]$Action = 'Gui',
    [string]$GameRoot,
    [string]$LauncherIni,
    [ValidateSet('Auto', 'LegacyRTX', 'NativeRTX')]
    [string]$Profile = 'Auto'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'FrameGenNG.Core.psm1') -Force

function Format-StatusText {
    param($Status)
    if (-not [bool]$Status.installed) {
        return "Non installé`r`nLe jeu n'a pas encore été modifié par ce package."
    }
    if ([bool]$Status.healthy) {
        return "Installé et intact`r`nVersion $($Status.version) · $($Status.profile) · $($Status.gpu)"
    }
    $broken = @($Status.checks | Where-Object { -not $_.matchesInstalled }).Count
    return "Réparation recommandée`r`n$broken élément(s) manquant(s) ou modifié(s)."
}

function Invoke-CommandLineAction {
    switch ($Action) {
        'Install' {
            $result = Install-FrameGenNG -GameRoot $GameRoot -LauncherIni $LauncherIni -Profile $Profile
            Write-Host "FrameGenNG $($result.version) installe avec le profil $($result.profile)." -ForegroundColor Green
        }
        'Repair' {
            $result = Repair-FrameGenNG -GameRoot $GameRoot -LauncherIni $LauncherIni
            Write-Host "FrameGenNG $($result.version) repare avec succes." -ForegroundColor Green
        }
        'Uninstall' {
            $result = Uninstall-FrameGenNG -GameRoot $GameRoot -LauncherIni $LauncherIni
            Write-Host "FrameGenNG desinstalle. Les fichiers d origine ont ete restaures." -ForegroundColor Green
            Write-Host "Sauvegarde conservee : $($result.backupKept)"
        }
        'Status' {
            Get-FrameGenNGStatus -GameRoot $GameRoot -LauncherIni $LauncherIni | ConvertTo-Json -Depth 10
        }
    }
}

if ($Action -ne 'Gui') {
    try {
        Invoke-CommandLineAction
        exit 0
    } catch {
        Write-Host "Erreur : $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$colors = @{
    Window = [System.Drawing.Color]::FromArgb(30, 32, 35)
    Panel = [System.Drawing.Color]::FromArgb(39, 42, 46)
    Border = [System.Drawing.Color]::FromArgb(66, 70, 76)
    Text = [System.Drawing.Color]::FromArgb(242, 243, 245)
    Muted = [System.Drawing.Color]::FromArgb(177, 181, 187)
    Accent = [System.Drawing.Color]::FromArgb(242, 112, 35)
    Success = [System.Drawing.Color]::FromArgb(74, 191, 123)
    Warning = [System.Drawing.Color]::FromArgb(242, 183, 76)
    Danger = [System.Drawing.Color]::FromArgb(221, 85, 85)
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "FrameGenNG Manager"
$form.StartPosition = 'CenterScreen'
$form.ClientSize = New-Object System.Drawing.Size(700, 540)
$form.MinimumSize = New-Object System.Drawing.Size(716, 579)
$form.BackColor = $colors.Window
$form.ForeColor = $colors.Text
$form.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)
$form.MaximizeBox = $false

$title = New-Object System.Windows.Forms.Label
$title.Text = 'FrameGenNG'
$title.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 22)
$title.ForeColor = $colors.Text
$title.Location = New-Object System.Drawing.Point(28, 22)
$title.AutoSize = $true
$form.Controls.Add($title)

$subtitle = New-Object System.Windows.Forms.Label
$subtitle.Text = 'Frame Generation for BeamNG.drive'
$subtitle.Font = New-Object System.Drawing.Font('Segoe UI', 10)
$subtitle.ForeColor = $colors.Muted
$subtitle.Location = New-Object System.Drawing.Point(31, 63)
$subtitle.AutoSize = $true
$form.Controls.Add($subtitle)

$versionLabel = New-Object System.Windows.Forms.Label
$versionLabel.Text = "Version $(Get-FrameGenNGVersion)"
$versionLabel.ForeColor = $colors.Muted
$versionLabel.TextAlign = 'MiddleRight'
$versionLabel.Location = New-Object System.Drawing.Point(515, 29)
$versionLabel.Size = New-Object System.Drawing.Size(155, 24)
$form.Controls.Add($versionLabel)

$statusPanel = New-Object System.Windows.Forms.Panel
$statusPanel.Location = New-Object System.Drawing.Point(28, 96)
$statusPanel.Size = New-Object System.Drawing.Size(642, 88)
$statusPanel.BackColor = $colors.Panel
$statusPanel.BorderStyle = 'FixedSingle'
$form.Controls.Add($statusPanel)

$statusDot = New-Object System.Windows.Forms.Label
$statusDot.Text = '●'
$statusDot.Font = New-Object System.Drawing.Font('Segoe UI', 15)
$statusDot.Location = New-Object System.Drawing.Point(17, 20)
$statusDot.Size = New-Object System.Drawing.Size(26, 32)
$statusDot.ForeColor = $colors.Muted
$statusPanel.Controls.Add($statusDot)

$statusText = New-Object System.Windows.Forms.Label
$statusText.Text = 'Vérification…'
$statusText.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 10.5)
$statusText.Location = New-Object System.Drawing.Point(51, 18)
$statusText.Size = New-Object System.Drawing.Size(565, 55)
$statusText.ForeColor = $colors.Text
$statusPanel.Controls.Add($statusText)

$gameLabel = New-Object System.Windows.Forms.Label
$gameLabel.Text = 'Installation BeamNG'
$gameLabel.ForeColor = $colors.Muted
$gameLabel.Location = New-Object System.Drawing.Point(28, 207)
$gameLabel.AutoSize = $true
$form.Controls.Add($gameLabel)

$gamePathBox = New-Object System.Windows.Forms.TextBox
$gamePathBox.Location = New-Object System.Drawing.Point(28, 228)
$gamePathBox.Size = New-Object System.Drawing.Size(642, 27)
$gamePathBox.ReadOnly = $true
$gamePathBox.BackColor = $colors.Panel
$gamePathBox.ForeColor = $colors.Text
$gamePathBox.BorderStyle = 'FixedSingle'
$form.Controls.Add($gamePathBox)

$userLabel = New-Object System.Windows.Forms.Label
$userLabel.Text = 'Dossier utilisateur BeamNG'
$userLabel.ForeColor = $colors.Muted
$userLabel.Location = New-Object System.Drawing.Point(28, 271)
$userLabel.AutoSize = $true
$form.Controls.Add($userLabel)

$userPathBox = New-Object System.Windows.Forms.TextBox
$userPathBox.Location = New-Object System.Drawing.Point(28, 292)
$userPathBox.Size = New-Object System.Drawing.Size(642, 27)
$userPathBox.ReadOnly = $true
$userPathBox.BackColor = $colors.Panel
$userPathBox.ForeColor = $colors.Text
$userPathBox.BorderStyle = 'FixedSingle'
$form.Controls.Add($userPathBox)

function New-ActionButton {
    param([string]$Text, [int]$X, [int]$Width, [System.Drawing.Color]$BackColor)
    $button = New-Object System.Windows.Forms.Button
    $button.Text = $Text
    $button.Location = New-Object System.Drawing.Point($X, 348)
    $button.Size = New-Object System.Drawing.Size($Width, 44)
    $button.FlatStyle = 'Flat'
    $button.FlatAppearance.BorderSize = 0
    $button.BackColor = $BackColor
    $button.ForeColor = [System.Drawing.Color]::White
    $button.Cursor = [System.Windows.Forms.Cursors]::Hand
    return $button
}

$installButton = New-ActionButton -Text 'Installer' -X 28 -Width 150 -BackColor $colors.Accent
$repairButton = New-ActionButton -Text 'Réparer' -X 190 -Width 150 -BackColor ([System.Drawing.Color]::FromArgb(69, 105, 144))
$uninstallButton = New-ActionButton -Text 'Désinstaller' -X 352 -Width 150 -BackColor ([System.Drawing.Color]::FromArgb(112, 70, 70))
$diagnosticButton = New-ActionButton -Text 'Diagnostic' -X 514 -Width 156 -BackColor ([System.Drawing.Color]::FromArgb(67, 70, 76))
$form.Controls.AddRange(@($installButton, $repairButton, $uninstallButton, $diagnosticButton))

$logBox = New-Object System.Windows.Forms.TextBox
$logBox.Location = New-Object System.Drawing.Point(28, 414)
$logBox.Size = New-Object System.Drawing.Size(642, 94)
$logBox.Multiline = $true
$logBox.ReadOnly = $true
$logBox.ScrollBars = 'Vertical'
$logBox.BackColor = [System.Drawing.Color]::FromArgb(24, 26, 29)
$logBox.ForeColor = $colors.Muted
$logBox.BorderStyle = 'FixedSingle'
$logBox.Font = New-Object System.Drawing.Font('Consolas', 9)
$logBox.Text = 'Prêt.'
$form.Controls.Add($logBox)

$script:resolvedGameRoot = $null
$script:resolvedUserRoot = $null

function Set-BusyState {
    param([bool]$Busy)
    foreach ($button in @($installButton, $repairButton, $uninstallButton, $diagnosticButton)) {
        $button.Enabled = -not $Busy
    }
    $form.UseWaitCursor = $Busy
    [System.Windows.Forms.Application]::DoEvents()
}

function Write-ManagerLog {
    param([string]$Message)
    $logBox.AppendText("`r`n$((Get-Date).ToString('HH:mm:ss'))  $Message")
    $logBox.SelectionStart = $logBox.TextLength
    $logBox.ScrollToCaret()
}

function Refresh-ManagerStatus {
    try {
        $script:resolvedGameRoot = Resolve-BeamNGGameRoot -GameRoot $GameRoot
        $script:resolvedUserRoot = Resolve-BeamNGUserRoot -LauncherIni $LauncherIni
        $gamePathBox.Text = $script:resolvedGameRoot
        $userPathBox.Text = $script:resolvedUserRoot
        $status = Get-FrameGenNGStatus -GameRoot $script:resolvedGameRoot -LauncherIni $LauncherIni
        $statusText.Text = Format-StatusText -Status $status
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
        $statusText.Text = "Configuration invalide`r`n$($_.Exception.Message)"
        $statusDot.ForeColor = $colors.Danger
        $gamePathBox.Text = if ($null -ne $GameRoot) { $GameRoot } else { 'Package non placé dans la racine BeamNG' }
        $userPathBox.Text = 'Indisponible'
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
            "GPU : $($detected.Gpu)`r`nProfil : $($detected.Profile)`r`n`r`nFrameGenNG va sauvegarder les fichiers existants puis installer la couche graphique. Continuer ?",
            'Installer FrameGenNG', 'YesNo', 'Question')
        if ($answer -ne 'Yes') { return }
        Write-ManagerLog -Message 'Installation en cours…'
        $result = Install-FrameGenNG -GameRoot $script:resolvedGameRoot -LauncherIni $LauncherIni -Profile $Profile
        Write-ManagerLog -Message "Installation terminée : $($result.profile)."
        [System.Windows.Forms.MessageBox]::Show('FrameGenNG est installé. Lancez BeamNG en DirectX 12 et activez DLSS.', 'Installation terminée', 'OK', 'Information') | Out-Null
    } catch {
        Write-ManagerLog -Message "Erreur : $($_.Exception.Message)"
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Installation impossible', 'OK', 'Error') | Out-Null
    } finally {
        Set-BusyState -Busy $false
        Refresh-ManagerStatus | Out-Null
    }
})

$repairButton.Add_Click({
    try {
        $answer = [System.Windows.Forms.MessageBox]::Show("La réparation restaure d’abord l’installation précédente, puis réinstalle ce package. Continuer ?", 'Réparer FrameGenNG', 'YesNo', 'Question')
        if ($answer -ne 'Yes') { return }
        Set-BusyState -Busy $true
        Write-ManagerLog -Message 'Réparation en cours…'
        Repair-FrameGenNG -GameRoot $script:resolvedGameRoot -LauncherIni $LauncherIni | Out-Null
        Write-ManagerLog -Message 'Réparation terminée.'
        [System.Windows.Forms.MessageBox]::Show('FrameGenNG a été réparé.', 'Réparation terminée', 'OK', 'Information') | Out-Null
    } catch {
        Write-ManagerLog -Message "Erreur : $($_.Exception.Message)"
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Réparation impossible', 'OK', 'Error') | Out-Null
    } finally {
        Set-BusyState -Busy $false
        Refresh-ManagerStatus | Out-Null
    }
})

$uninstallButton.Add_Click({
    try {
        $answer = [System.Windows.Forms.MessageBox]::Show("Les fichiers d’origine sauvegardés seront restaurés. Les sauvegardes seront conservées. Désinstaller FrameGenNG ?", 'Désinstaller FrameGenNG', 'YesNo', 'Warning')
        if ($answer -ne 'Yes') { return }
        Set-BusyState -Busy $true
        Write-ManagerLog -Message "Restauration des fichiers d’origine…"
        $result = Uninstall-FrameGenNG -GameRoot $script:resolvedGameRoot -LauncherIni $LauncherIni
        Write-ManagerLog -Message "Désinstallation terminée. Sauvegarde : $($result.backupKept)"
        [System.Windows.Forms.MessageBox]::Show("FrameGenNG est désinstallé et les fichiers d’origine ont été restaurés.", 'Désinstallation terminée', 'OK', 'Information') | Out-Null
    } catch {
        Write-ManagerLog -Message "Erreur : $($_.Exception.Message)"
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Désinstallation impossible', 'OK', 'Error') | Out-Null
    } finally {
        Set-BusyState -Busy $false
        Refresh-ManagerStatus | Out-Null
    }
})

$diagnosticButton.Add_Click({
    try {
        Set-BusyState -Busy $true
        $status = Get-FrameGenNGStatus -GameRoot $script:resolvedGameRoot -LauncherIni $LauncherIni
        if (-not [bool]$status.installed) {
            Write-ManagerLog -Message "Diagnostic : FrameGenNG n’est pas installé."
        } elseif ([bool]$status.healthy) {
            Write-ManagerLog -Message "Diagnostic : installation intacte, profil $($status.profile)."
        } else {
            $broken = @($status.checks | Where-Object { -not $_.matchesInstalled })
            Write-ManagerLog -Message "Diagnostic : $($broken.Count) élément(s) à réparer."
            foreach ($entry in $broken) { Write-ManagerLog -Message "À réparer : $($entry.destination)" }
        }
    } catch {
        Write-ManagerLog -Message "Erreur de diagnostic : $($_.Exception.Message)"
    } finally {
        Set-BusyState -Busy $false
        Refresh-ManagerStatus | Out-Null
    }
})

$form.Add_Shown({ Refresh-ManagerStatus | Out-Null })
[void]$form.ShowDialog()

