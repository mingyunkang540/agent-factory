#Requires -Version 7.4
Set-StrictMode -Version Latest

function Read-AfJson {
    param([Parameter(Mandatory)][string]$Path)
    Get-Content -LiteralPath $Path -Raw -Encoding utf8 | ConvertFrom-Json -AsHashtable
}

function Write-AfJson {
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)]$Value)
    $full = [IO.Path]::GetFullPath($Path)
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($full)) | Out-Null
    $temp = "$full.$([guid]::NewGuid().ToString('N')).tmp"
    try {
        [IO.File]::WriteAllText($temp, ($Value | ConvertTo-Json -Depth 100), [Text.UTF8Encoding]::new($false))
        [IO.File]::Move($temp, $full, $true)
    } finally { if ([IO.File]::Exists($temp)) { [IO.File]::Delete($temp) } }
}

function Get-AfProjectRoot {
    param([Parameter(Mandatory)][string]$ProjectPath)
    $root = (Resolve-Path -LiteralPath $ProjectPath -ErrorAction Stop).Path
    if (-not [IO.Directory]::Exists($root) -or -not (Test-Path -LiteralPath (Join-Path $root 'agent-factory.json') -PathType Leaf)) {
        throw 'Project root must contain agent-factory.json.'
    }
    return $root
}

function Assert-AfRoadmap {
    param([Parameter(Mandatory)]$Roadmap)
    if ($Roadmap -isnot [Collections.IDictionary] -or -not $Roadmap.Contains('schema_version') -or
        -not $Roadmap.Contains('tasks') -or $Roadmap.schema_version -ne 1 -or $Roadmap.tasks -isnot [array]) {
        throw 'Invalid roadmap schema: expected schema_version 1 and a tasks array.'
    }
    $ids = [Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
    foreach ($task in $Roadmap.tasks) {
        if ($task -isnot [Collections.IDictionary]) { throw 'Each roadmap task must be an object.' }
        foreach ($field in @('id','title','priority','status','acceptance','depends_on')) {
            if (-not $task.Contains($field)) { throw "Missing task field: $field" }
        }
        if ($task.id -isnot [string] -or $task.id -cnotmatch '^TASK-[0-9]{3,}$' -or $ids.ContainsKey($task.id)) { throw 'Invalid or duplicate task ID.' }
        if ($task.title -isnot [string] -or [string]::IsNullOrWhiteSpace($task.title)) { throw "Missing title: $($task.id)" }
        if ($task.priority -isnot [int] -and $task.priority -isnot [long]) { throw "Invalid priority: $($task.id)" }
        if ($task.priority -lt 1 -or $task.status -cnotin @('todo','in_progress','done','blocked')) { throw "Invalid task state: $($task.id)" }
        if ($task.acceptance -isnot [array] -or $task.acceptance.Count -eq 0) { throw "Missing acceptance: $($task.id)" }
        foreach ($criterion in $task.acceptance) { if ($criterion -isnot [string] -or [string]::IsNullOrWhiteSpace($criterion)) { throw 'Invalid acceptance criterion.' } }
        if ($task.depends_on -isnot [array]) { throw "Invalid dependencies: $($task.id)" }
        $ids.Add($task.id, $task)
    }
    $remaining = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($task in $Roadmap.tasks) {
        [void]$remaining.Add($task.id)
        foreach ($dependency in $task.depends_on) {
            if ($dependency -isnot [string] -or -not $ids.ContainsKey($dependency)) { throw "Unknown dependency: $dependency" }
            if ($task.status -eq 'done' -and $ids[$dependency].status -ne 'done') {
                throw "Done task $($task.id) has an incomplete dependency: $dependency"
            }
        }
    }
    while ($remaining.Count -gt 0) {
        $ready = @($remaining | Where-Object { $id = $_; @($ids[$id].depends_on | Where-Object { $remaining.Contains($_) }).Count -eq 0 })
        if ($ready.Count -eq 0) { throw 'Roadmap dependencies contain a cycle.' }
        foreach ($id in $ready) { [void]$remaining.Remove($id) }
    }
}

function New-AfStatus {
    return @{ schema_version=1; initialized=$false; current_task=$null; blocked=$false; block_reason=$null
        quality=@{lint='unknown';typecheck='unknown';test='unknown';build='unknown';tester='unknown';reviewer='unknown';security='unknown'}
        approvals=@{product=$null;mvp=$null;release=$null};last_run=$null;last_quality=$null;history=@() }
}

function Get-AfRoadmapDefinition {
    param([string]$ProjectPath)
    $path = Join-Path $ProjectPath 'docs/ROADMAP.json'
    if (-not (Test-Path -LiteralPath $path)) { return '' }
    if (((Get-Item -LiteralPath $path).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw 'ROADMAP.json must not be a symbolic link or reparse point.'
    }
    $roadmap = Read-AfJson $path
    Assert-AfRoadmap $roadmap
    $tasks = @($roadmap.tasks | Sort-Object id | ForEach-Object {
        [ordered]@{id=$_.id;title=$_.title;priority=$_.priority;acceptance=@($_.acceptance);depends_on=@($_.depends_on | Sort-Object)}
    })
    return (ConvertTo-Json -InputObject $tasks -Depth 100 -Compress)
}

function Get-AfContentFingerprint {
    param([string]$ProjectPath, [string[]]$Files)
    $entries = [Collections.Generic.List[string]]::new()
    foreach ($file in $Files) {
        $path = Join-Path $ProjectPath $file
        if ([IO.File]::Exists($path)) { $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash; $entries.Add("$file`:$hash") }
        else { $entries.Add("$file`:missing") }
    }
    $entries.Add('roadmap:' + (Get-AfRoadmapDefinition $ProjectPath))
    $bytes = [Text.Encoding]::UTF8.GetBytes(($entries -join "`n"))
    return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
}

function Get-AfFingerprint {
    param([Parameter(Mandatory)][string]$ProjectPath)
    $root = Get-AfProjectRoot $ProjectPath
    $pending = [Collections.Generic.Stack[string]]::new()
    $pending.Push($root)
    $paths = [Collections.Generic.List[string]]::new()
    while ($pending.Count -gt 0) {
        $directory = $pending.Pop()
        if (([IO.File]::GetAttributes($directory) -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Source directory must not be a symbolic link or reparse point: $directory"
        }
        foreach ($entry in Get-ChildItem -LiteralPath $directory -Force -ErrorAction Stop) {
            if ($entry.PSIsContainer -and $entry.Name -in @('.git','node_modules','dist','coverage','.agent-factory','.omx')) { continue }
            $relative = [IO.Path]::GetRelativePath($root, $entry.FullName).Replace('\','/')
            if ($relative -match '^docs/(STATUS|ROADMAP)\.json$' -or $relative -match '^docs/(PR|RELEASE)([_-].*)?\.(md|json)$') { continue }
            if (($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw "Source entry must not be a symbolic link or reparse point: $relative"
            }
            if ($entry.PSIsContainer) { $pending.Push($entry.FullName) } else { $paths.Add($relative) }
        }
    }
    $files = $paths.ToArray()
    [Array]::Sort($files, [StringComparer]::Ordinal)
    Get-AfContentFingerprint $root $files
}

function Get-AfPlanFingerprint {
    param([Parameter(Mandatory)][string]$ProjectPath)
    Get-AfContentFingerprint (Get-AfProjectRoot $ProjectPath) @('IDEA.md','docs/PRD.md','docs/ARCHITECTURE.md','docs/UX.md','docs/DECISIONS.md')
}

function Invoke-AfProcess {
    param([Parameter(Mandatory)][string]$File, [string[]]$Arguments=@(), [Parameter(Mandatory)][string]$WorkingDirectory,
        [Parameter(Mandatory)][string]$LogPath, [AllowNull()][string]$InputText=$null, [int]$TimeoutSeconds=900)
    if ($TimeoutSeconds -lt 1) { throw 'Timeout must be positive.' }
    $command = Get-Command $File -CommandType Application,ExternalScript -ErrorAction Stop | Select-Object -First 1
    $executable = $command.Source
    $prefix = @()
    if ($File -in @('npm','npm.cmd','npm.ps1') -and
        ($IsWindows -or [IO.Path]::GetExtension($executable) -in @('.ps1','.cmd'))) {
        $npmCli = Join-Path (Split-Path $executable -Parent) 'node_modules/npm/bin/npm-cli.js'
        if (-not (Test-Path -LiteralPath $npmCli)) { throw 'Installed npm CLI was not found.' }
        $executable = (Get-Command node -CommandType Application -ErrorAction Stop).Source
        $prefix = @($npmCli)
    } elseif ([IO.Path]::GetExtension($executable) -eq '.ps1') {
        $prefix = @('-NoProfile','-NonInteractive','-File',$executable)
        $executable = (Get-Command pwsh -CommandType Application -ErrorAction Stop).Source
    } elseif ([IO.Path]::GetExtension($executable) -in @('.cmd','.bat')) { throw 'Batch launchers are not supported; use a native executable or PowerShell script.' }
    $info = [Diagnostics.ProcessStartInfo]::new()
    $info.FileName=$executable; $info.WorkingDirectory=$WorkingDirectory; $info.UseShellExecute=$false
    $info.RedirectStandardOutput=$true; $info.RedirectStandardError=$true; $info.RedirectStandardInput=$true
    $info.StandardInputEncoding=[Text.UTF8Encoding]::new($false); $info.StandardOutputEncoding=[Text.UTF8Encoding]::new($false); $info.StandardErrorEncoding=[Text.UTF8Encoding]::new($false)
    foreach ($argument in @($prefix) + @($Arguments)) { $info.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::new(); $process.StartInfo=$info
    $readCancellation = [Threading.CancellationTokenSource]::new()
    try {
        [void]$process.Start()
        $clock = [Diagnostics.Stopwatch]::StartNew()
        $readCancellation.CancelAfter([TimeSpan]::FromSeconds($TimeoutSeconds))
        $stdoutTask=$process.StandardOutput.ReadToEndAsync($readCancellation.Token)
        $stderrTask=$process.StandardError.ReadToEndAsync($readCancellation.Token)
        $timedOut = $false
        if ($null -ne $InputText) {
            $inputTask = $process.StandardInput.WriteAsync($InputText)
            $timedOut = -not $inputTask.Wait($TimeoutSeconds * 1000)
        }
        if (-not $timedOut) {
            $process.StandardInput.Close()
            $remaining = [Math]::Max(0, ($TimeoutSeconds * 1000) - [int]$clock.ElapsedMilliseconds)
            $timedOut = -not $process.WaitForExit($remaining)
        }
        if (-not $timedOut) {
            # A descendant may retain inherited pipes after the original process exits.
            # Pipe draining shares the command deadline rather than waiting indefinitely.
            $remaining = [Math]::Max(0, ($TimeoutSeconds * 1000) - [int]$clock.ElapsedMilliseconds)
            try { $timedOut = -not [Threading.Tasks.Task]::WhenAll([Threading.Tasks.Task[]]@($stdoutTask,$stderrTask)).Wait($remaining) }
            catch { if ($readCancellation.IsCancellationRequested) { $timedOut=$true } else { throw } }
        }
        if ($timedOut) {
            $readCancellation.Cancel()
            if (-not $process.HasExited) { $process.Kill($true); if (-not $process.WaitForExit(5000)) { throw 'Process did not stop after timeout.' } }
        }
        $stdout=if ($stdoutTask.IsCompletedSuccessfully) { $stdoutTask.GetAwaiter().GetResult() } else { '' }
        $stderr=if ($stderrTask.IsCompletedSuccessfully) { $stderrTask.GetAwaiter().GetResult() } else { '' }
        if ($timedOut) { $stderr += "`nCommand or output drain exceeded the timeout; incomplete output was discarded." }
        $exitCode=if ($timedOut) { 124 } else { $process.ExitCode }
        $result=@{exit_code=$exitCode;stdout=$stdout;stderr=$stderr;timed_out=$timedOut}
        [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($LogPath))) | Out-Null
        [IO.File]::WriteAllText($LogPath, "exit_code=$($result.exit_code) timed_out=$timedOut`nSTDOUT`n$stdout`nSTDERR`n$stderr", [Text.UTF8Encoding]::new($false))
        return $result
    } finally {
        $readCancellation.Cancel()
        try {
            if (-not $process.HasExited) { $process.Kill($true); [void]$process.WaitForExit(5000) }
        } catch { # Process may not have started or may already have exited.
        }
        $process.Dispose()
        $readCancellation.Dispose()
    }
}

function Get-AfNextTask {
    param([Parameter(Mandatory)]$Roadmap)
    Assert-AfRoadmap $Roadmap
    $done=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($task in $Roadmap.tasks) { if ($task.status -eq 'done') { [void]$done.Add($task.id) } }
    $eligible=@($Roadmap.tasks | Where-Object { $_.status -eq 'todo' -and @($_.depends_on | Where-Object { -not $done.Contains($_) }).Count -eq 0 })
    if ($eligible.Count -eq 0) { return $null }
    $minimum=($eligible | Measure-Object priority -Minimum).Minimum
    $same=@($eligible | Where-Object { $_.priority -eq $minimum })
    $ids=[string[]]@($same | ForEach-Object { $_.id }); [Array]::Sort($ids,[StringComparer]::Ordinal)
    return ($same | Where-Object { $_.id -ceq $ids[0] } | Select-Object -First 1)
}

function Enter-AfLock {
    param([Parameter(Mandatory)][string]$ProjectPath)
    $directory=Join-Path (Get-AfProjectRoot $ProjectPath) '.agent-factory'
    [IO.Directory]::CreateDirectory($directory) | Out-Null
    try { return [IO.File]::Open((Join-Path $directory 'run.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None) }
    catch { throw 'Project is locked by another Agent Factory operation.' }
}

function Invoke-AfQuality {
    param([Parameter(Mandatory)][string]$ProjectPath)
    $root=Get-AfProjectRoot $ProjectPath
    $config=Read-AfJson (Join-Path $root 'agent-factory.json')
    $fingerprint=Get-AfFingerprint $root
    $checks=@{}; $passed=$true
    $runId=[DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffffff') + '-' + [guid]::NewGuid().ToString('N')
    foreach ($name in @('lint','typecheck','test','build')) {
        $log=Join-Path $root ".agent-factory/logs/$runId-$name.log"
        $check=@{status='missing';exit_code=$null;log=$log}
        try {
            if (-not $config.ContainsKey('commands') -or -not $config.commands.ContainsKey($name)) { throw "Missing command: $name" }
            $definition=$config.commands[$name]
            if ($definition.file -isnot [string] -or [string]::IsNullOrWhiteSpace($definition.file) -or $definition.args -isnot [array]) { throw "Invalid command: $name" }
            foreach ($arg in $definition.args) { if ($arg -isnot [string]) { throw 'Command arguments must be strings.' } }
            if ($definition.file -in @('npm','npm.cmd','npm.ps1') -and $definition.args.Count -ge 2 -and $definition.args[0] -eq 'run') {
                $package=Read-AfJson (Join-Path $root 'package.json')
                if (-not $package.ContainsKey('scripts') -or -not $package.scripts.ContainsKey($definition.args[1])) { throw "Missing npm script: $($definition.args[1])" }
            }
            $check.status='fail'
            $result=Invoke-AfProcess -File $definition.file -Arguments $definition.args -WorkingDirectory $root -LogPath $log
            $check.exit_code=$result.exit_code
            if ($result.exit_code -eq 0 -and -not $result.timed_out) { $check.status='pass' }
        } catch {
            [IO.Directory]::CreateDirectory((Split-Path $log -Parent)) | Out-Null
            [IO.File]::WriteAllText($log,$_.Exception.Message,[Text.UTF8Encoding]::new($false))
        }
        if ($check.status -ne 'pass') { $passed=$false }
        $checks[$name]=$check
    }
    $after=Get-AfFingerprint $root
    if ($after -ne $fingerprint) { $passed=$false }
    $report=@{schema_version=1;passed=$passed;fingerprint=$fingerprint;checked_at=[DateTime]::UtcNow.ToString('o');checks=$checks;source_unchanged=($after -eq $fingerprint)}
    Write-AfJson (Join-Path $root '.agent-factory/quality.json') $report
    return $report
}
