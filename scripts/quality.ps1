#Requires -Version 7.4
[CmdletBinding()]
param([string]$ProjectPath='.')
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'common.ps1')
. (Join-Path $PSScriptRoot 'state.ps1')
$lock=$null
try {
    $root=Get-AfProjectRoot $ProjectPath
    $lock=Enter-AfLock $root
    Repair-AfStateTransaction $root
    $statusPath=Join-Path $root 'docs/STATUS.json'
    $status=if (Test-Path -LiteralPath $statusPath) { Read-AfJson $statusPath } else { New-AfStatus }
    $previous=$status.last_quality
    $report=Invoke-AfQuality $root
    foreach ($name in @('lint','typecheck','test','build')) { $status.quality[$name]=$report.checks[$name].status }
    if ($null -eq $previous -or $previous.fingerprint -ne $report.fingerprint -or -not $report.source_unchanged -or
        -not $report.passed -or -not $previous.passed) {
        foreach ($name in @('tester','reviewer','security')) { $status.quality[$name]='unknown' }
    }
    $status.last_quality=$report
    Write-AfJson $statusPath $status
    foreach ($name in @('lint','typecheck','test','build')) { Write-Output "$name`: $($report.checks[$name].status)" }
    if ($report.passed) { exit 0 } else { exit 1 }
} catch { Write-Error $_ -ErrorAction Continue; exit 2 }
finally { if ($null -ne $lock) { $lock.Dispose() } }
