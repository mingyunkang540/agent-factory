#requires -Version 7.4
# A journal makes the two versioned state files a recoverable transaction.
function Repair-AfStateTransaction {
    param([Parameter(Mandatory)][string]$ProjectPath, [switch]$Quiet)
    $journalPath = Join-Path $ProjectPath '.agent-factory/state-transaction.json'
    if (-not (Test-Path -LiteralPath $journalPath -PathType Leaf)) { return }
    $journal = Read-AfJson $journalPath
    if ($journal.schema_version -ne 1 -or $journal.status.schema_version -ne 1) { throw 'Invalid state transaction journal; manual inspection required.' }
    Assert-AfRoadmap $journal.roadmap
    $pending = @($journal.roadmap.tasks | Where-Object { $_.status -in @('in_progress','blocked') })
    if ($pending.Count -gt 1 -or ($pending.Count -eq 1 -and $journal.status.current_task -cne $pending[0].id) -or
        ($pending.Count -eq 0 -and $journal.status.current_task)) { throw 'Inconsistent state transaction journal; manual inspection required.' }
    Write-AfJson (Join-Path $ProjectPath 'docs/ROADMAP.json') $journal.roadmap
    Write-AfJson (Join-Path $ProjectPath 'docs/STATUS.json') $journal.status
    Remove-Item -LiteralPath $journalPath -ErrorAction Stop
    if (-not $Quiet) { Write-Host 'Recovered the interrupted state transaction. An in-progress task still requires explicit resume.' }
}

function Write-AfStateTransaction {
    param([Parameter(Mandatory)][string]$ProjectPath, [Parameter(Mandatory)]$Roadmap, [Parameter(Mandatory)]$Status)
    Assert-AfRoadmap $Roadmap
    $journalPath = Join-Path $ProjectPath '.agent-factory/state-transaction.json'
    Write-AfJson $journalPath @{schema_version=1;roadmap=$Roadmap;status=$Status}
    Repair-AfStateTransaction $ProjectPath -Quiet
}
