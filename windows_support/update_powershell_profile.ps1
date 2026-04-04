param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('add', 'remove')]
    [string]$Action,

    [Parameter(Mandatory = $true)]
    [string]$InstallBin
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$startMarker = '# >>> AuraGamblingSuite >>>'
$endMarker = '# <<< AuraGamblingSuite <<<'

function Get-ProfileTargets {
    $targets = @(
        (Join-Path $HOME 'Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1'),
        (Join-Path $HOME 'Documents\PowerShell\Microsoft.PowerShell_profile.ps1')
    )

    return @($targets | Select-Object -Unique)
}

function Get-ManagedBlock {
    param([string]$BinPath)

    $escapedBin = $BinPath.Replace("'", "''")
    $launchers = @('cf', 'rps', 'sl', 'sc', 'bj', 'vp')
    $lines = @(
        $startMarker,
        ('$AuraSuiteBin = ''{0}''' -f $escapedBin)
    )

    foreach ($name in $launchers) {
        $lines += ('function global:{0} {{ & (Join-Path $AuraSuiteBin ''{0}.cmd'') @args }}' -f $name)
    }

    $lines += @(
        'Remove-Variable AuraSuiteBin -ErrorAction SilentlyContinue',
        $endMarker
    )

    return ($lines -join [Environment]::NewLine)
}

function Update-ProfileFile {
    param(
        [string]$Path,
        [string]$Mode,
        [string]$Block
    )

    $directory = Split-Path -Parent $Path
    if (-not (Test-Path $directory)) {
        [void](New-Item -ItemType Directory -Path $directory -Force)
    }

    $content = ''
    if (Test-Path $Path) {
        $content = Get-Content -Path $Path -Raw
    }

    $pattern = [regex]::Escape($startMarker) + '.*?' + [regex]::Escape($endMarker)
    $content = [regex]::Replace($content, $pattern, '', [System.Text.RegularExpressions.RegexOptions]::Singleline).Trim()

    if ($Mode -eq 'add') {
        if ($content) {
            $content += [Environment]::NewLine + [Environment]::NewLine
        }
        $content += $Block
    }

    if ($content) {
        Set-Content -Path $Path -Value ($content + [Environment]::NewLine) -Encoding ASCII
    } elseif (Test-Path $Path) {
        Clear-Content -Path $Path
    }
}

$managedBlock = Get-ManagedBlock -BinPath $InstallBin
foreach ($profilePath in (Get-ProfileTargets)) {
    Update-ProfileFile -Path $profilePath -Mode $Action -Block $managedBlock
}
