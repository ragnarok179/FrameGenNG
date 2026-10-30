function ConvertFrom-FrameGenNGJsonFile {
    param([Parameter(Mandatory)][string]$Path)

    Add-Type -AssemblyName System.Web.Extensions
    $serializer = New-Object System.Web.Script.Serialization.JavaScriptSerializer
    $serializer.MaxJsonLength = [int]::MaxValue
    $serializer.RecursionLimit = 512
    return $serializer.DeserializeObject([System.IO.File]::ReadAllText($Path))
}

function Test-FrameGenNGJsonProperty {
    param(
        [Parameter(Mandatory)]$Object,
        [Parameter(Mandatory)][string]$Name
    )

    if ($Object -is [System.Collections.IDictionary]) {
        return @($Object.Keys) -ccontains $Name
    }
    return $Object.PSObject.Properties.Name -ccontains $Name
}

function Get-FrameGenNGJsonProperty {
    param(
        [Parameter(Mandatory)]$Object,
        [Parameter(Mandatory)][string]$Name
    )

    if ($Object -is [System.Collections.IDictionary]) {
        return $Object[$Name]
    }
    return $Object.PSObject.Properties[$Name].Value
}

function Set-FrameGenNGJsonProperty {
    param(
        [Parameter(Mandatory)]$Object,
        [Parameter(Mandatory)][string]$Name,
        [AllowNull()]$Value
    )

    if ($Object -is [System.Collections.IDictionary]) {
        $Object[$Name] = $Value
        return
    }
    $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value -Force
}

function Remove-FrameGenNGJsonProperty {
    param(
        [Parameter(Mandatory)]$Object,
        [Parameter(Mandatory)][string]$Name
    )

    if ($Object -is [System.Collections.IDictionary]) {
        $Object.Remove($Name)
        return
    }
    $Object.PSObject.Properties.Remove($Name)
}
