# Registrations

Register-ArgumentCompleter -Native -CommandName dotnet -ScriptBlock {
    param($commandName, $wordToComplete, $cursorPosition)
    dotnet complete --position $cursorPosition "$wordToComplete" | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}

Set-PSReadLineOption -PredictionSource History

# Shows navigable menu of all options when hitting Tab
Set-PSReadlineKeyHandler -Key Tab -Function MenuComplete

# Autocompletion for arrow keys
Set-PSReadlineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadlineKeyHandler -Key DownArrow -Function HistorySearchForward

Set-Alias cd cdh -Option AllScope

$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
    Import-Module "$ChocolateyProfile"
}

# PWSH linq

function skip {
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [Object[]] $collection,
        [Parameter(Mandatory, Position = 1)]
        [int] $count    
    )
    begin {
        $skipped = 0
    }
    process {
        if ($skipped -lt $count) {
            $skipped++
        }
        else {
            $_
        }
    }
}

function take {
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [Object[]] $collection,
        [Parameter(Mandatory, Position = 1)]
        [int] $count
    )
    begin {
        $taken = 0
    }
    process {   
        if ($taken -lt $count) {      
            $taken++
            $_
        }
    }
}

function skipWhile {
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [Object[]] $collection,
        [Parameter(Mandatory, Position = 1)]
        [scriptblock]$pred
    )
    begin {
        $skip = $true
    }
    process {
        if ( $skip ) {
            $skip = & $pred $_
        }

        if ( -not $skip ) {
            $_
        }
    }
}

function takeWhile {
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [Object[]] $collection,
        [Parameter(Mandatory, Position = 1)]
        [scriptblock]$pred
    )
    begin {
        $take = $true
    }
    process {
        if ($take -and (& $pred $_)) {
            $_
        }
        else {
            $take = $false
        }
    }
}

function skipUntil {
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [Object[]] $collection,
        [Parameter(Mandatory, Position = 1)]
        [scriptblock]$pred,
        [switch] $inc
    )
    begin {
        $skip = $true
    }
    process {
        if ( $skip ) {
            $skip = -not (& $pred $_)
        }

        if ( -not $skip ) {
            if ($inc) {
                $inc = $false
            }
            else {
                $_
            }
        }
    }
}

function takeUntil {
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [Object[]] $collection,
        [Parameter(Mandatory, Position = 1)]
        [scriptblock]$pred,
        [switch] $inc
    )
    begin {
        $take = $true
    }
    process {
        if ($take -and (-not (& $pred $_))) {
            $_
        }
        else {
            $take = $false
            if ($inc) {
                $_
            }
        }
    }
}

function takeRange {
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [Object[]] $collection,
        [Parameter(Mandatory, Position = 1)]
        [scriptblock]$startPred,
        [Parameter(Mandatory, Position = 2)]
        [scriptblock]$endPred,
        [switch] $exc

    )
    begin {
        $started = $false
        $take = $true
    }
    process {
        if (-not $started) {
            $started = & $startPred $_

            if ($started) {
                $_
            }
        }
        else {
            if ($take) {
                if (-not (& $endPred $_)) {
                    $_
                }
                else {
                    $take = $false
                    if (-not $exc) {
                        $_
                    }
                }
            }
        }
    }
}

function map {
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [Object[]] $collection,
        [Parameter(Mandatory, Position = 1)]
        [scriptblock]$pred
    )  
    process {
        & $pred $_
    }
}

function get-column {
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string] $value,
        [Parameter(Mandatory, Position = 0)]
        [Int32] $index
    )
    ($value.Split([System.StringSplitOptions]::RemoveEmptyEntries))[$index]    
}

function newObj {
    param (
        [Parameter(Mandatory, Position = 1)]
        [hashtable] $table
    )
    return New-Object psobject -Property $table
}

# path utils

[System.Collections.Generic.List[string]]$locationHistory = @() #make this a file?
function cdh {

    param (
        [Parameter(Position = 1)]
        [Object] $index
    )

    if ($null -eq $index) {

        if ($locationHistory.Count -gt 0) {
            $counter = 0
            $locationHistory | foreach {
                $counter = $counter + 1
                $idx = $counter
                newObj @{ Id = $idx; Path = $_ }
            }
        }

        return
    }

    [int]$int = 0
    if ($index.GetType().Equals($int.GetType())) {
        $int = $index        

        Set-Location -Path $locationHistory[$int - 1]

        return
    }

    [string]$str = ""
    if ($index.GetType().Equals($str.GetType())) {
        $str = $index
        $res = Set-Location -Path $str -PassThru
        if ($null -ne $res) {
            if ($false -eq $locationHistory.Contains($res.Path)) {
                $locationHistory.Add($res.Path)
            }
        }

        return
    }
}

function cdhclear {
    $locationHistory.Clear()
}

function cdx {
    $upOneLevel = @("..")
    $continue = $true
    while ($continue) {
        $dirs = Get-ChildItem -dir -Name -Force
        $menu = $upOneLevel + $dirs | ocgv -OutputMode Single
        if ($menu.Count -eq 0) {
            $continue = $false 
        }  
        else {
            cdh $menu
        }
    }
}

function cdb {
    param (
        [Parameter(Mandatory, Position = 1)]
        [String] $location
    )
    [System.IO.DirectoryInfo]$dirInfo = New-Object IO.DirectoryInfo((Get-Location).Path)
    $dirInfo = $dirInfo.Parent
  
    while ($null -ne $dirInfo) {
        if ($dirInfo.Name.Contains($location, [System.StringComparison]::OrdinalIgnoreCase) -eq $true) {      
            break;
        }
        $dirInfo = $dirInfo.Parent
    }

    if ($null -ne $dirInfo) {
        cdh $dirInfo.FullName
    }
}

function cdf {
    param (
        [Parameter(Mandatory, Position = 1)]
        [String] $location
    )
    [System.IO.DirectoryInfo]$dirInfo = New-Object IO.DirectoryInfo((Get-Location).Path)
    $childDirs = $dirInfo.GetDirectories()
    
    if ($childDirs.Count -gt 0) {
        $idx = 0
        while ($idx -lt $childDirs.Count) {
            $dirInfo = $childDirs[$idx]
            if ($dirInfo.Name.Contains($location, [System.StringComparison]::OrdinalIgnoreCase) -eq $true) {      
                break;
            }
            $idx = $idx + 1
            $dirInfo = $null
        }
    }

    if ($null -ne $dirInfo) {
        cdh $dirInfo.FullName
    }
}

# system

function printenv {
    dir env:
}

function Get-Processes {
    return Get-Process | map { newObj @{ Name = $_.Name; Id = $_.Id; CommandLine = $_.CommandLine; Value = $_ } }
}

# dotnet

function fss {
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [String] $code
    )
    $tempFile = New-TemporaryFile
    $name = $tempFile.BaseName + ".fsx"
    Rename-Item $tempFile.FullName $name

    try {
        $code | Out-File $name
        dotnet fsi $name
    }
    finally {
        Remove-Item $name
    }
}

function Get-DotnetProcesses {
    return Get-Process | where { $_.Name.Contains("dotnet") } | map { newObj @{ Name = $_.Name; Id = $_.Id; CommandLine = $_.CommandLine; Value = $_ } }
}

# dotnet nuget 

function Nuget-PackToLocal {
    dotnet pack -c Release -o "$Env:NugetPath\$Env:NugetLocalServerName" --include-symbols --version-suffix $Env:NugetLocalServerName
}

function Nuget-PushToLocal {
    param (
        [string]$path
    )
    dotnet nuget push --source "$Env:NugetPath\$Env:NugetLocalServerName" $path
}

# Powershell .Net syntax

# type
# [Namespace.TypeName...]                        [System.StringComparison]

# enum field
# [Type]::Value                                  [System.StringComparison]::OrdinalIgnoreCase

# method
# [Type]::Method(args)                           [System.Linq.Enumerable]::Where($data, [Func[object,bool]]{ param($x) $x -gt 5 })

# generic type
# [Type[TypeArgs...]]                            [Func[object,bool]]

# ctor call
# New-Object Namespace.TypeName(args...)         New-Object IO.FileInfo($_)
# [TypeName]::new(args...)                       [IO.FileInfo]::new($_)

# using namespace
# using namespace NamespaceName                  using namespace System.IO

# Loading types
# Add-Type -Path "path to dll"