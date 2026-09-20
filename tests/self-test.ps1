#Requires -Version 7.4
[CmdletBinding()]
param([switch]$KeepArtifacts,[string]$NameFilter='*')
$ErrorActionPreference='Stop'
$factory=Split-Path $PSScriptRoot -Parent
. (Join-Path $factory 'scripts/common.ps1')
$scratch=Join-Path ([IO.Path]::GetTempPath()) ('agent factory 한글 '+[guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($scratch) | Out-Null
$script:passed=0; $script:failed=0
$fake=Join-Path $PSScriptRoot 'fixtures/fake-codex.ps1'
function Assert([bool]$Condition,[string]$Message='Assertion failed') { if (-not $Condition) { throw $Message } }
function Test([string]$Name,[scriptblock]$Body) {
    if ($Name -notlike $NameFilter) { return }
    try { & $Body; $script:passed++; Write-Host "PASS $Name" }
    catch { $script:failed++; Write-Host "FAIL $Name : $($_.Exception.Message)" -ForegroundColor Red }
}
function Invoke-TestCli([string]$Script,[string[]]$Arguments=@()) {
    $log=Join-Path $scratch ([guid]::NewGuid().ToString('N')+'.log')
    Invoke-AfProcess -File (Join-Path $factory "scripts/$Script.ps1") -Arguments $Arguments -WorkingDirectory $factory -LogPath $log -TimeoutSeconds 120
}
function Agent([string]$Action,[string]$Project,[string[]]$Extra=@()) { Invoke-TestCli 'agent' (@('-Action',$Action,'-ProjectPath',$Project,'-CodexCommand',$fake)+$Extra) }
function NewProject {
    $name='fixture-'+[guid]::NewGuid().ToString('N').Substring(0,8)
    $result=Invoke-TestCli 'new-app' @('-Name',$name,'-Destination',$scratch,'-NoGit')
    Assert ($result.exit_code -eq 0) $result.stderr
    $path=Join-Path $scratch $name
    [IO.File]::WriteAllText((Join-Path $path 'IDEA.md'), "# Fixture idea`nA small local list for one person. Add and view items; no backend or production deployment.`n", [Text.UTF8Encoding]::new($false))
    $config=Read-AfJson (Join-Path $path 'agent-factory.json')
    foreach ($check in @('lint','typecheck','test','build')) { $config.commands[$check]=@{file='node';args=@('-e','process.exit(0)')} }
    Write-AfJson (Join-Path $path 'agent-factory.json') $config
    return $path
}
function InitializedProject {
    $path=NewProject
    $result=Agent 'init' $path; Assert ($result.exit_code -eq 0) $result.stderr
    $result=Agent 'approve' $path @('-Gate','product'); Assert ($result.exit_code -eq 0) $result.stderr
    return $path
}
function Status([string]$Path) { Read-AfJson (Join-Path $Path 'docs/STATUS.json') }
function Roadmap([string]$Path) { Read-AfJson (Join-Path $Path 'docs/ROADMAP.json') }
function Calls([string]$Path) { @(Get-ChildItem -LiteralPath (Join-Path $Path '.agent-factory/fake-calls') -Filter '*.json' | ForEach-Object { Read-AfJson $_.FullName }) }
function Control([string]$Path,$Value) { Write-AfJson (Join-Path $Path '.agent-factory/fake-control.json') $Value }
function Task([string]$Id,[int]$Priority=1,[string[]]$Dependencies=@()) { @{id=$Id;title=$Id;priority=$Priority;status='todo';acceptance=@('Expected behavior');depends_on=@($Dependencies)} }
try {
    Test 'all PowerShell scripts parse without errors' {
        foreach ($file in Get-ChildItem -LiteralPath @((Join-Path $factory 'scripts'), $PSScriptRoot) -Filter '*.ps1' -Recurse) {
            $tokens=$null; $errors=$null
            [void][Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$tokens,[ref]$errors)
            Assert ($errors.Count -eq 0) ($errors | Out-String)
        }
    }
    Test 'subprocess timeout also bounds detached descendant output draining' {
        $timer=[Diagnostics.Stopwatch]::StartNew()
        $result=Invoke-AfProcess -File (Join-Path $PSScriptRoot 'fixtures/descendant-parent.ps1') -WorkingDirectory $scratch -LogPath (Join-Path $scratch 'descendant-timeout.log') -TimeoutSeconds 1
        $timer.Stop(); Assert $result.timed_out; Assert ($result.exit_code -eq 124); Assert ($timer.Elapsed.TotalSeconds -lt 3) 'Timeout did not bound output draining'
    }
    Test 'scaffolding supports paths with Korean characters and spaces' { $p=NewProject; Assert (Test-Path -LiteralPath (Join-Path $p 'automation/scripts/agent.ps1')) }
    Test 'scaffolding refuses existing project without overwriting' {
        $p=NewProject; $sentinel=Join-Path $p 'sentinel.txt'; Set-Content -LiteralPath $sentinel 'keep'
        $r=Invoke-TestCli 'new-app' @('-Name',(Split-Path $p -Leaf),'-Destination',$scratch,'-NoGit')
        Assert ($r.exit_code -ne 0); Assert ((Get-Content -LiteralPath $sentinel) -eq 'keep')
    }
    Test 'scaffolding rejects path traversal names' { $r=Invoke-TestCli 'new-app' @('-Name','../escape','-Destination',$scratch,'-NoGit'); Assert ($r.exit_code -ne 0) }
    Test 'scaffolding rejects unsupported preset' { $r=Invoke-TestCli 'new-app' @('-Name','bad-preset','-Preset','bogus','-Destination',$scratch,'-NoGit'); Assert ($r.exit_code -ne 0) }
    Test 'scaffolding refuses the unsupported Toss extension stub' { $r=Invoke-TestCli 'new-app' @('-Name','toss-stub','-Preset','toss-miniapp','-Destination',$scratch,'-NoGit'); Assert ($r.exit_code -ne 0); Assert (-not (Test-Path (Join-Path $scratch 'toss-stub'))) }
    Test 'scaffolding refuses the unsupported Unity extension stub' { $r=Invoke-TestCli 'new-app' @('-Name','unity-stub','-Preset','unity','-Destination',$scratch,'-NoGit'); Assert ($r.exit_code -ne 0); Assert (-not (Test-Path (Join-Path $scratch 'unity-stub'))) }
    Test 'task selection breaks priority ties by ordinal task ID' { $m=@{schema_version=1;tasks=@((Task 'TASK-002'),(Task 'TASK-001'))}; Assert ((Get-AfNextTask $m).id -eq 'TASK-001') }
    Test 'task selection waits for unfinished dependencies' { $m=@{schema_version=1;tasks=@((Task 'TASK-001' 2),(Task 'TASK-002' 1 @('TASK-001')))}; Assert ((Get-AfNextTask $m).id -eq 'TASK-001') }
    Test 'roadmap rejects dependency cycles' { $m=@{schema_version=1;tasks=@((Task 'TASK-001' 1 @('TASK-002')),(Task 'TASK-002' 2 @('TASK-001')))}; $rejected=$false; try { Assert-AfRoadmap $m } catch { $rejected=$true }; Assert $rejected }
    Test 'roadmap rejects duplicate task IDs' { $m=@{schema_version=1;tasks=@((Task 'TASK-001'),(Task 'TASK-001'))}; $rejected=$false; try { Assert-AfRoadmap $m } catch { $rejected=$true }; Assert $rejected }
    Test 'roadmap rejects unknown dependencies' { $m=@{schema_version=1;tasks=@((Task 'TASK-001' 1 @('TASK-999')))}; $rejected=$false; try { Assert-AfRoadmap $m } catch { $rejected=$true }; Assert $rejected }
    Test 'roadmap rejects a completed task with unfinished dependencies' { $first=Task 'TASK-001'; $second=Task 'TASK-002' 2 @('TASK-001'); $second.status='done'; $m=@{schema_version=1;tasks=@($first,$second)}; $rejected=$false; try { Assert-AfRoadmap $m } catch { $rejected=$true }; Assert $rejected }
    Test 'roadmap rejects missing required fields' { $m=@{schema_version=1;tasks=@(@{id='TASK-001'})}; $rejected=$false; try { Assert-AfRoadmap $m } catch { $rejected=$true }; Assert $rejected }
    Test 'fingerprint ignores excluded dependency content' { $p=NewProject; $before=Get-AfFingerprint $p; [void][IO.Directory]::CreateDirectory((Join-Path $p 'node_modules/fixture')); Set-Content -LiteralPath (Join-Path $p 'node_modules/fixture/source.js') 'dependency'; Assert ((Get-AfFingerprint $p) -eq $before) }
    Test 'init generates planning documents without changing implementation files' {
        $p=NewProject; $source=Join-Path $p 'src'; $before=@(Get-ChildItem $source -File -Recurse | Get-FileHash).Hash -join ','
        $r=Agent 'init' $p; Assert ($r.exit_code -eq 0) $r.stderr
        Assert ((Status $p).initialized); Assert ((Calls $p).Count -eq 3)
        Assert (($before) -eq (@(Get-ChildItem $source -File -Recurse | Get-FileHash).Hash -join ','))
    }
    Test 'next refuses implementation before product approval' { $p=NewProject; [void](Agent 'init' $p); $count=(Calls $p).Count; $r=Agent 'next' $p; Assert ($r.exit_code -ne 0); Assert ((Calls $p).Count -eq $count) }
    Test 'init refuses to overwrite existing planning' { $p=InitializedProject; $before=Get-Content (Join-Path $p 'docs/PRD.md') -Raw; $count=(Calls $p).Count; $r=Agent 'init' $p; Assert ($r.exit_code -ne 0); Assert ((Get-Content (Join-Path $p 'docs/PRD.md') -Raw) -eq $before); Assert ((Calls $p).Count -eq $count) }
    Test 'malformed product response leaves init uninitialized' { $p=NewProject; Control $p @{malformed_role='product'}; $before=Get-Content (Join-Path $p 'docs/PRD.md') -Raw; $r=Agent 'init' $p; Assert ($r.exit_code -ne 0); Assert (-not (Status $p).initialized); Assert ((Get-Content (Join-Path $p 'docs/PRD.md') -Raw) -eq $before) }
    Test 'next refuses product approval after planning content changes' { $p=InitializedProject; Add-Content -LiteralPath (Join-Path $p 'docs/PRD.md') 'Changed direction'; $count=(Calls $p).Count; $r=Agent 'next' $p; Assert ($r.exit_code -ne 0); Assert ((Calls $p).Count -eq $count) }
    Test 'dry run performs no Codex calls or status mutations' { $p=InitializedProject; $before=Get-Content (Join-Path $p 'docs/STATUS.json') -Raw; $count=(Calls $p).Count; $r=Agent 'next' $p @('-DryRun'); Assert ($r.exit_code -eq 0) $r.stderr; Assert ((Calls $p).Count -eq $count); Assert ((Get-Content (Join-Path $p 'docs/STATUS.json') -Raw) -eq $before) }
    Test 'next completes exactly one task and leaves the second todo' { $p=InitializedProject; $r=Agent 'next' $p; Assert ($r.exit_code -eq 0) $r.stderr; $m=Roadmap $p; Assert ($m.tasks[0].status -eq 'done'); Assert ($m.tasks[1].status -eq 'todo'); Assert (@(Calls $p | Where-Object role -eq 'implementer').Count -eq 1) }
    Test 'independent verification sessions receive read-only sandbox arguments' {
        $p=InitializedProject; $r=Agent 'next' $p; Assert ($r.exit_code -eq 0) $r.stderr
        foreach ($role in @('tester','reviewer','security')) {
            $call=@(Calls $p | Where-Object role -eq $role); Assert ($call.Count -eq 1)
            $sandboxIndex=[Array]::IndexOf($call[0].arguments,'--sandbox'); Assert ($sandboxIndex -ge 0); Assert ($call[0].arguments[$sandboxIndex+1] -eq 'read-only')
            $approvalIndex=[Array]::IndexOf($call[0].arguments,'-a'); Assert ($approvalIndex -ge 0); Assert ($call[0].arguments[$approvalIndex+1] -eq 'never')
            Assert (-not ($call[0].arguments -contains 'approvals_reviewer="auto_review"'))
        }
    }
    Test 'implementation session receives workspace write with automatic approval review' {
        $p=InitializedProject; $r=Agent 'next' $p; Assert ($r.exit_code -eq 0) $r.stderr
        $call=@(Calls $p | Where-Object role -eq 'implementer'); Assert ($call.Count -eq 1)
        $sandboxIndex=[Array]::IndexOf($call[0].arguments,'--sandbox'); Assert ($sandboxIndex -ge 0); Assert ($call[0].arguments[$sandboxIndex+1] -eq 'workspace-write')
        $approvalIndex=[Array]::IndexOf($call[0].arguments,'-a'); Assert ($approvalIndex -ge 0); Assert ($call[0].arguments[$approvalIndex+1] -eq 'on-request')
        Assert ($call[0].arguments -contains 'approvals_reviewer="auto_review"')
    }
    Test 'passing reviews may include acceptance evidence findings' {
        $p=InitializedProject; Control $p @{evidence_findings=$true}
        $r=Agent 'next' $p; Assert ($r.exit_code -eq 0) $r.stderr
        Assert ((Roadmap $p).tasks[0].status -eq 'done')
        foreach ($role in @('tester','reviewer','security')) {
            $call=@(Calls $p | Where-Object role -eq $role); Assert ($call.Count -eq 1)
        }
    }
    Test 'failed independent review blocks after three implementation attempts' { $p=InitializedProject; Control $p @{fail_role='reviewer'}; $r=Agent 'next' $p; Assert ($r.exit_code -ne 0); Assert ((Status $p).blocked); Assert ((Roadmap $p).tasks[0].status -ne 'done'); Assert (@(Calls $p | Where-Object role -eq 'implementer').Count -eq 3) }
    Test 'malformed independent verdict never completes a task' { $p=InitializedProject; Control $p @{malformed_role='security'}; $r=Agent 'next' $p; Assert ($r.exit_code -ne 0); Assert ((Roadmap $p).tasks[0].status -ne 'done') }
    Test 'malformed implementation response blocks after three attempts' { $p=InitializedProject; Control $p @{malformed_role='implementer'}; $r=Agent 'next' $p; Assert ($r.exit_code -ne 0); Assert ((Status $p).blocked); Assert (@(Calls $p | Where-Object role -eq 'implementer').Count -eq 3) }
    Test 'controller status tampering blocks without retrying altered controls' { $p=InitializedProject; Control $p @{tamper_status=$true}; $r=Agent 'next' $p; Assert ($r.exit_code -ne 0); Assert ((Status $p).blocked); Assert ((Roadmap $p).tasks[0].status -ne 'done'); Assert (@(Calls $p | Where-Object role -eq 'implementer').Count -eq 1) }
    Test 'failed real command blocks even when AI verdicts would pass' { $p=InitializedProject; $c=Read-AfJson (Join-Path $p 'agent-factory.json'); $c.commands.test=@{file='node';args=@('-e','process.exit(1)')}; Write-AfJson (Join-Path $p 'agent-factory.json') $c; $r=Agent 'next' $p; Assert ($r.exit_code -ne 0); Assert ((Status $p).blocked); Assert ((Roadmap $p).tasks[0].status -ne 'done'); Assert (@(Calls $p | Where-Object role -eq 'implementer').Count -eq 3) }
    Test 'run stops immediately on a blocker' { $p=InitializedProject; Control $p @{fail_role='tester'}; $r=Agent 'run' $p @('-Count','5'); Assert ($r.exit_code -ne 0); Assert ((Roadmap $p).tasks[1].status -eq 'todo'); Assert (@(Calls $p | Where-Object role -eq 'implementer').Count -eq 3) }
    Test 'run rejects counts above five' { $p=InitializedProject; $count=(Calls $p).Count; $r=Agent 'run' $p @('-Count','6'); Assert ($r.exit_code -ne 0); Assert ((Calls $p).Count -eq $count) }
    Test 'run completes no more than its requested count' {
        $p=NewProject; Control $p @{tasks=@((Task 'TASK-001'),(Task 'TASK-002'),(Task 'TASK-003'))}
        $r=Agent 'init' $p; Assert ($r.exit_code -eq 0) $r.stderr
        $r=Agent 'approve' $p @('-Gate','product'); Assert ($r.exit_code -eq 0) $r.stderr
        $r=Agent 'run' $p @('-Count','2'); Assert ($r.exit_code -eq 0) $r.stderr
        Assert (@((Roadmap $p).tasks | Where-Object status -eq 'done').Count -eq 2)
        Assert ((Roadmap $p).tasks[2].status -eq 'todo')
    }
    Test 'missing npm scripts fail the real command quality gate' { $p=NewProject; $c=Read-AfJson (Join-Path $p 'agent-factory.json'); $c.commands.test=@{file='npm';args=@('run','not-a-script')}; Write-AfJson (Join-Path $p 'agent-factory.json') $c; $r=Invoke-TestCli 'quality' @('-ProjectPath',$p); Assert ($r.exit_code -ne 0); Assert ((Status $p).quality.test -eq 'missing') }
    Test 'failed current commands invalidate earlier passing independent reviews' {
        $p=NewProject; $c=Read-AfJson (Join-Path $p 'agent-factory.json'); $c.commands.test=@{file='node';args=@('-e','process.exit(process.env.AF_SELF_TEST_FAIL === "1" ? 1 : 0)')}; Write-AfJson (Join-Path $p 'agent-factory.json') $c
        $r=Agent 'init' $p; Assert ($r.exit_code -eq 0) $r.stderr
        [void](Agent 'approve' $p @('-Gate','product')); $r=Agent 'next' $p; Assert ($r.exit_code -eq 0) $r.stderr
        $prior=[Environment]::GetEnvironmentVariable('AF_SELF_TEST_FAIL')
        try { [Environment]::SetEnvironmentVariable('AF_SELF_TEST_FAIL','1'); $r=Invoke-TestCli 'quality' @('-ProjectPath',$p); Assert ($r.exit_code -ne 0); Assert ((Status $p).quality.reviewer -eq 'unknown') }
        finally { [Environment]::SetEnvironmentVariable('AF_SELF_TEST_FAIL',$prior) }
    }
    Test 'overlapping project operations are rejected by the lock' { $p=InitializedProject; $lock=Enter-AfLock $p; try { $r=Agent 'next' $p; Assert ($r.exit_code -ne 0) } finally { $lock.Dispose() } }
    Test 'resume clears a blocked task without implementing it' { $p=InitializedProject; Control $p @{fail_role='reviewer'}; [void](Agent 'next' $p); $count=(Calls $p).Count; $r=Agent 'resume' $p; Assert ($r.exit_code -eq 0) $r.stderr; Assert (-not (Status $p).blocked); Assert ((Roadmap $p).tasks[0].status -eq 'todo'); Assert ((Calls $p).Count -eq $count) }
    Test 'PR preparation refuses stale source evidence' { $p=InitializedProject; $r=Agent 'next' $p; Assert ($r.exit_code -eq 0) $r.stderr; Add-Content -LiteralPath (Join-Path $p 'IDEA.md') 'changed'; $r=Agent 'pr' $p; Assert ($r.exit_code -ne 0) }
    Test 'PR preparation makes no Git mutations' { $p=InitializedProject; [void](Agent 'next' $p); $r=Agent 'pr' $p; Assert ($r.exit_code -eq 0) $r.stderr; Assert (-not (Test-Path -LiteralPath (Join-Path $p '.git'))) }
    Test 'release refuses missing human gates' { $p=InitializedProject; [void](Agent 'run' $p @('-Count','2')); $r=Agent 'release' $p; Assert ($r.exit_code -ne 0) }
    Test 'release succeeds after complete tasks and three current human gates' {
        $p=InitializedProject; $r=Agent 'run' $p @('-Count','2'); Assert ($r.exit_code -eq 0) $r.stderr
        foreach ($gate in @('mvp','release')) { $r=Agent 'approve' $p @('-Gate',$gate); Assert ($r.exit_code -eq 0) $r.stderr }
        $r=Agent 'release' $p; Assert ($r.exit_code -eq 0) $r.stderr
        $readiness=Read-AfJson (Join-Path $p '.agent-factory/release.json'); Assert $readiness.ready; Assert (-not $readiness.deployment_executed)
    }
    Test 'init refuses an unedited IDEA template without model calls' {
        $p=NewProject
        Copy-Item -LiteralPath (Join-Path $factory 'template/IDEA.md') -Destination (Join-Path $p 'IDEA.md')
        $r=Agent 'init' $p
        Assert ($r.exit_code -ne 0); Assert (-not (Status $p).initialized)
        Assert (-not (Test-Path -LiteralPath (Join-Path $p '.agent-factory/fake-calls')))
    }
    Test 'interrupted state transaction recovers both files and still requires resume' {
        $p=InitializedProject; $m=Roadmap $p; $s=Status $p; $count=(Calls $p).Count
        $m.tasks[0].status='in_progress'; $s.current_task='TASK-001'
        Write-AfJson (Join-Path $p '.agent-factory/state-transaction.json') @{schema_version=1;roadmap=$m;status=$s}
        Write-AfJson (Join-Path $p 'docs/ROADMAP.json') $m
        $r=Agent 'status' $p; Assert ($r.exit_code -eq 0) $r.stderr
        Assert ((Status $p).current_task -eq 'TASK-001')
        Assert (-not (Test-Path -LiteralPath (Join-Path $p '.agent-factory/state-transaction.json')))
        $r=Agent 'next' $p; Assert ($r.exit_code -ne 0)
        $r=Agent 'resume' $p; Assert ($r.exit_code -eq 0) $r.stderr
        Assert ((Roadmap $p).tasks[0].status -eq 'todo'); Assert ((Calls $p).Count -eq $count)
    }
    Test 'interrupted completion transaction recovers a finished task without rerunning it' {
        $p=InitializedProject; $r=Agent 'next' $p; Assert ($r.exit_code -eq 0) $r.stderr
        $m=Roadmap $p; $s=Status $p; $count=(Calls $p).Count
        Write-AfJson (Join-Path $p '.agent-factory/state-transaction.json') @{schema_version=1;roadmap=$m;status=$s}
        $old=Status $p; $old.current_task='TASK-001'; Write-AfJson (Join-Path $p 'docs/STATUS.json') $old
        $r=Agent 'status' $p; Assert ($r.exit_code -eq 0) $r.stderr
        Assert ($null -eq (Status $p).current_task); Assert ((Roadmap $p).tasks[0].status -eq 'done'); Assert ((Calls $p).Count -eq $count)
    }
    Test 'generated profile preserves Factory ai-new for another project' {
        $p=NewProject; $probe=Join-Path $scratch 'profile-probe.ps1'
        $probeBody=@'
param([string]$Factory,[string]$Project,[string]$Destination)
. (Join-Path $Factory 'scripts/profile.ps1')
. (Join-Path $Project 'automation/scripts/profile.ps1')
ai-new another-project -Destination $Destination -NoGit
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
ai-status -ProjectPath $Project
'@
        [IO.File]::WriteAllText($probe,$probeBody,[Text.UTF8Encoding]::new($false))
        $r=Invoke-AfProcess -File $probe -Arguments @('-Factory',$factory,'-Project',$p,'-Destination',$scratch) -WorkingDirectory $scratch -LogPath (Join-Path $scratch 'profile-probe.log')
        Assert ($r.exit_code -eq 0) $r.stderr
        Assert (Test-Path -LiteralPath (Join-Path $scratch 'another-project/agent-factory.json'))
    }
    Test 'status marks prior passing evidence stale after source changes' {
        $p=InitializedProject; $r=Agent 'next' $p; Assert ($r.exit_code -eq 0) $r.stderr
        Add-Content -LiteralPath (Join-Path $p 'src/App.tsx') '// Manual correction'
        $r=Agent 'status' $p; Assert ($r.exit_code -eq 0) $r.stderr
        $display=$r.stdout | ConvertFrom-Json -AsHashtable
        Assert (-not $display.evidence_current); Assert ($display.quality.test -eq 'stale')
    }
    Test 'review refresh restores current evidence without implementation or task advancement' {
        $p=InitializedProject; $r=Agent 'next' $p; Assert ($r.exit_code -eq 0) $r.stderr
        $m=Get-Content -LiteralPath (Join-Path $p 'docs/ROADMAP.json') -Raw
        Add-Content -LiteralPath (Join-Path $p 'src/App.tsx') '// Manual correction'
        Control $p @{evidence_findings=$true}
        $r=Agent 'pr' $p; Assert ($r.exit_code -ne 0)
        $r=Agent 'review' $p; Assert ($r.exit_code -eq 0) $r.stderr
        Assert ((Get-Content -LiteralPath (Join-Path $p 'docs/ROADMAP.json') -Raw) -eq $m)
        Assert (@(Calls $p | Where-Object role -eq 'implementer').Count -eq 1)
        foreach ($role in @('tester','reviewer','security')) { Assert (@(Calls $p | Where-Object role -eq $role).Count -eq 2) }
        $r=Agent 'pr' $p; Assert ($r.exit_code -eq 0) $r.stderr
    }
    Test 'failed review refresh blocks PR and preserves task state' {
        $p=InitializedProject; $r=Agent 'next' $p; Assert ($r.exit_code -eq 0) $r.stderr
        Control $p @{fail_role='security'}
        $r=Agent 'review' $p; Assert ($r.exit_code -ne 0)
        Assert ((Status $p).quality.security -eq 'fail'); Assert ((Roadmap $p).tasks[0].status -eq 'done')
        $r=Agent 'pr' $p; Assert ($r.exit_code -ne 0)
    }
} finally {
    Write-Host "Self-test: $script:passed passed, $script:failed failed. Fake Codex validates orchestration only; no API calls."
    if ($KeepArtifacts -or $script:failed -gt 0) { Write-Host "Artifacts: $scratch" }
    else { $resolved=[IO.Path]::GetFullPath($scratch); Assert ($resolved.StartsWith([IO.Path]::GetFullPath([IO.Path]::GetTempPath()),[StringComparison]::OrdinalIgnoreCase)); Remove-Item -LiteralPath $resolved -Recurse -Force }
}
if ($script:failed -gt 0) { exit 1 }
