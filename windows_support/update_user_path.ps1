param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('add', 'remove')]
    [string]$Action,

    [Parameter(Mandatory = $true)]
    [string]$PathEntry
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Normalize-PathEntry {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $null
    }

    $expanded = [Environment]::ExpandEnvironmentVariables($Value.Trim())
    try {
        return [System.IO.Path]::GetFullPath($expanded).TrimEnd('\')
    } catch {
        return $expanded.TrimEnd('\')
    }
}

$target = Normalize-PathEntry -Value $PathEntry
$current = [Environment]::GetEnvironmentVariable('Path', 'User')
$entries = @()
if ($current) {
    $entries = $current -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
}

$seen = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
$updatedEntries = New-Object 'System.Collections.Generic.List[string]'

foreach ($entry in $entries) {
    $normalizedEntry = Normalize-PathEntry -Value $entry
    if (-not $normalizedEntry) {
        continue
    }

    if ($Action -eq 'remove' -and [System.StringComparer]::OrdinalIgnoreCase.Equals($normalizedEntry, $target)) {
        continue
    }

    if ($seen.Add($normalizedEntry)) {
        [void]$updatedEntries.Add($entry)
    }
}

if ($Action -eq 'add' -and $seen.Add($target)) {
    [void]$updatedEntries.Add($target)
}

[Environment]::SetEnvironmentVariable('Path', ($updatedEntries -join ';'), 'User')

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

namespace Aura
{
    public static class NativeMethods
    {
        [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
        public static extern IntPtr SendMessageTimeout(
            IntPtr hWnd,
            int Msg,
            IntPtr wParam,
            string lParam,
            int fuFlags,
            int uTimeout,
            out IntPtr lpdwResult
        );
    }
}
"@

$nullResult = [IntPtr]::Zero
[void][Aura.NativeMethods]::SendMessageTimeout(
    [IntPtr]0xffff,
    0x001A,
    [IntPtr]::Zero,
    'Environment',
    0x0002,
    5000,
    [ref]$nullResult
)
