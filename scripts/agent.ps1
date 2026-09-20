#requires -Version 7.4
[CmdletBinding()]
param(
    [Parameter(Mandatory, Position=0)][ValidateSet('init','next','run','status','approve','resume','review','pr','release')][string]$Action,
    [Parameter(Position=1)][ValidateRange(1,5)][int]$Count = 3,
    [string]$ProjectPath = '.',
    [ValidateSet('product','mvp','release')][string]$Gate = 'product',
    [string]$Note = 'Approved by the human operator.',
    [switch]$DryRun,
    [string]$CodexCommand = 'codex',
    [string]$Model,
    [ValidateRange(1,3600)][int]$TimeoutSeconds = 900
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')
. (Join-Path $PSScriptRoot 'state.ps1')
. (Join-Path $PSScriptRoot 'codex.ps1')
. (Join-Path $PSScriptRoot 'workflow.ps1')
$lock = $null
try {
    $root = Get-AfProjectRoot $ProjectPath
    $lock = Enter-AfLock $root
    if ($DryRun -and (Test-Path -LiteralPath (Join-Path $root '.agent-factory/state-transaction.json'))) {
        throw 'A pending state transaction exists; run status to recover it before a dry run.'
    }
    Repair-AfStateTransaction $root
    $config = Read-AfJson (Join-Path $root 'agent-factory.json')
    if ($config.schema_version -ne 1 -or $config.max_attempts -notin @(1,2,3) -or $config.max_tasks_per_run -notin @(1,2,3,4,5)) { throw 'Invalid Factory schema or configured execution limits.' }
    $roadmap = Read-AfJson (Join-Path $root 'docs/ROADMAP.json')
    Assert-AfRoadmap $roadmap
    $status = Read-AfJson (Join-Path $root 'docs/STATUS.json')
    if ($status.schema_version -ne 1 -or $status.quality -isnot [System.Collections.IDictionary] -or $status.approvals -isnot [System.Collections.IDictionary]) { throw 'Invalid STATUS schema.' }
    $roleArgs = @{ProjectPath=$root;CodexCommand=$CodexCommand;Model=$Model;TimeoutSeconds=$TimeoutSeconds}
    $context = @{root=$root;config=$config;roadmap=$roadmap;status=$status;roleArgs=$roleArgs}
    if ($Action -eq 'run' -and $Count -gt $config.max_tasks_per_run) { throw 'Count exceeds configured max_tasks_per_run.' }
    if ($DryRun) {
        if ($Action -notin @('init','next','run')) { throw 'DryRun is supported for init, next and run only.' }
        $selected = Get-AfNextTask $roadmap
        @{action=$Action;project=$config.project;next_task=$selected;max_cycles=$(if ($Action -eq 'run') {$Count} else {1});max_attempts=$config.max_attempts;model_calls=0} | ConvertTo-Json -Depth 20
    }
    else {
        switch ($Action) {
            init { Invoke-AfInitialize $context }
            next { [void](Invoke-AfNext $context) }
            run {
                for ($index=0; $index -lt $Count; $index++) {
                    if (-not (Invoke-AfNext $context)) { break }
                }
            }
            status {
                $fingerprint = Get-AfFingerprint $root
                $current = $null -ne $status.last_quality -and $status.last_quality.fingerprint -eq $fingerprint
                $displayQuality = @{}
                foreach ($key in $status.quality.Keys) {
                    $displayQuality[$key] = if (-not $current -and $status.quality[$key] -eq 'pass') { 'stale' } else { $status.quality[$key] }
                }
                @{project=$config.project;current_task=$status.current_task;completed=@($roadmap.tasks | Where-Object status -eq 'done').Count;
                    remaining=@($roadmap.tasks | Where-Object status -ne 'done').Count;blocked=$status.blocked;block_reason=$status.block_reason;
                    initialized=$status.initialized;evidence_current=$current;quality=$displayQuality;approvals=$status.approvals;last_run=$status.last_run} | ConvertTo-Json -Depth 20
            }
            approve { Invoke-AfApproval $context $Gate $Note }
            resume { Invoke-AfResume $context }
            review { Invoke-AfRefreshReview $context }
            pr { Invoke-AfPrPreparation $context }
            release { Invoke-AfReleaseCheck $context }
        }
    }
    exit 0
}
catch { Write-Error -Message $_.Exception.Message -ErrorAction Continue; exit 1 }
finally { if ($lock) { $lock.Dispose() } }
