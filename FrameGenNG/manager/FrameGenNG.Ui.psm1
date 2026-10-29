Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-FrameGenNGManagerLayout {
    param(
        [Parameter(Mandatory)][int]$StatusHeight,
        [bool]$Expanded = $false
    )

    $statusTop = 23
    $effectiveStatusHeight = [Math]::Max(38, $StatusHeight)
    $actionTop = $statusTop + $effectiveStatusHeight + 7
    $updateTop = $actionTop + 42
    $secondaryActionTop = $updateTop + 44
    $logTop = $secondaryActionTop + 40
    $footerTop = if ($Expanded) { $logTop + 148 } else { $secondaryActionTop + 48 }

    return [pscustomobject]@{
        StatusTop = $statusTop
        StatusHeight = $effectiveStatusHeight
        ActionTop = $actionTop
        UpdateTop = $updateTop
        SecondaryActionTop = $secondaryActionTop
        LogTop = $logTop
        FooterTop = $footerTop
        FormHeight = $footerTop + 56
    }
}

function New-FrameGenNGDialog {
    param(
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][int]$Width,
        [Parameter(Mandatory)][int]$Height,
        [Parameter(Mandatory)]$Colors
    )

    $dialog = New-Object System.Windows.Forms.Form
    $dialog.Text = $Title
    $dialog.StartPosition = 'CenterParent'
    $dialog.ClientSize = New-Object System.Drawing.Size($Width, $Height)
    $dialog.MinimumSize = New-Object System.Drawing.Size($Width, $Height)
    $dialog.BackColor = $Colors.Window
    $dialog.ForeColor = $Colors.Text
    $dialog.Font = New-Object System.Drawing.Font('Segoe UI', 9)
    $dialog.FormBorderStyle = 'FixedDialog'
    $dialog.MaximizeBox = $false
    $dialog.MinimizeBox = $false
    $dialog.ShowIcon = $false
    return $dialog
}

function New-FrameGenNGButton {
    param(
        [Parameter(Mandatory)][string]$Text,
        [Parameter(Mandatory)][int]$X,
        [Parameter(Mandatory)][int]$Y,
        [Parameter(Mandatory)][int]$Width,
        [Parameter(Mandatory)][int]$Height,
        [Parameter(Mandatory)]$Colors,
        [ValidateSet('Accent', 'Secondary', 'Danger')][string]$Style = 'Secondary',
        [string]$Anchor = 'Top,Left',
        [string]$DialogResult
    )

    $button = New-Object System.Windows.Forms.Button
    $button.Text = $Text
    $button.Location = New-Object System.Drawing.Point($X, $Y)
    $button.Size = New-Object System.Drawing.Size($Width, $Height)
    $button.Anchor = $Anchor
    $button.FlatStyle = 'System'
    $button.UseVisualStyleBackColor = $true
    $button.Font = New-Object System.Drawing.Font('Segoe UI', 9)

    if (-not [string]::IsNullOrWhiteSpace($DialogResult)) {
        $button.DialogResult = $DialogResult
    }
    return $button
}

Export-ModuleMember -Function @(
    'Get-FrameGenNGManagerLayout',
    'New-FrameGenNGDialog',
    'New-FrameGenNGButton'
)
