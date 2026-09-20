$CliArguments=[string[]]$args
$ErrorActionPreference='Stop'
$prompt=[Console]::In.ReadToEnd()
function ArgumentValue([string]$Name) {
    $index=[Array]::IndexOf($CliArguments,$Name)
    if ($index -lt 0) { throw "Missing $Name" }
    return $CliArguments[$index+1]
}
$output=ArgumentValue '--output-last-message'
$schema=Get-Content -LiteralPath (ArgumentValue '--output-schema') -Raw | ConvertFrom-Json -AsHashtable
$role=([IO.Path]::GetFileName($output) -split '[-_.]' | Where-Object { $_ -in @('product','architect','ux','implementer','tester','reviewer','security','release') } | Select-Object -First 1)
if (-not $role) {
    foreach ($candidate in @('product','architect','ux','implementer','tester','reviewer','security','release')) {
        if ($prompt -match "(?i)\b$candidate\b") { $role=$candidate; break }
    }
}
$controlPath=Join-Path (Get-Location) '.agent-factory/fake-control.json'
$control=if (Test-Path -LiteralPath $controlPath) { Get-Content -LiteralPath $controlPath -Raw | ConvertFrom-Json -AsHashtable } else { @{} }
$traceDirectory=Join-Path (Get-Location) '.agent-factory/fake-calls'
[void][IO.Directory]::CreateDirectory($traceDirectory)
$trace=Join-Path $traceDirectory ([guid]::NewGuid().ToString('N')+'.json')
[IO.File]::WriteAllText($trace,(@{role=$role;arguments=$CliArguments;output=$output} | ConvertTo-Json -Depth 20),[Text.UTF8Encoding]::new($false))
if ($control['malformed_role'] -eq $role) { [IO.File]::WriteAllText($output,'not JSON'); exit 0 }
if ($control['exit_role'] -eq $role) { exit 1 }
if ($role -eq 'implementer' -and $control['tamper_status']) {
    $statePath=Join-Path (Get-Location) 'docs/STATUS.json'
    $state=Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json -AsHashtable
    $state.block_reason='Unauthorized fixture mutation'
    [IO.File]::WriteAllText($statePath,($state | ConvertTo-Json -Depth 30))
}
$taskId=[regex]::Match($prompt,'TASK-ID:\s*(TASK-\d{3,})').Groups[1].Value
if (-not $taskId) { $taskId=[regex]::Match($prompt,'TASK-\d{3,}').Value }
if (-not $taskId) { $taskId='TASK-001' }
$tasks=@(
    @{id='TASK-001';title='First fixture slice';priority=1;status='todo';acceptance=@('Fixture behavior verified');depends_on=@()},
    @{id='TASK-002';title='Second fixture slice';priority=2;status='todo';acceptance=@('Second fixture behavior verified');depends_on=@()}
)
if ($control.ContainsKey('tasks')) { $tasks=$control.tasks }
switch ($role) {
    product { $config=Get-Content -LiteralPath 'agent-factory.json' -Raw | ConvertFrom-Json; $result=@{prd='# Fixture PRD';roadmap=@{schema_version=1;project=$config.project;tasks=$tasks}} }
    architect { $result=@{architecture='# Fixture Architecture';decisions='# Fixture Decisions'} }
    ux { $result=@{ux='# Fixture UX'} }
    implementer { $result=@{task_id=$taskId;summary='Fixture implementation attempt'} }
    default {
        $verdict=if ($control['fail_role'] -eq $role) {'fail'} else {'pass'}
        $findings=[Collections.Generic.List[string]]::new()
        if ($control['evidence_findings'] -and $verdict -eq 'pass') { $findings.Add('Acceptance evidence confirmed.') }
        $result=@{task_id=$taskId;verdict=$verdict;summary='Fixture independent verdict';findings=$findings}
    }
}
[IO.File]::WriteAllText($output,($result | ConvertTo-Json -Depth 30),[Text.UTF8Encoding]::new($false))
