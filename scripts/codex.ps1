#requires -Version 7.4
# This library is dot-sourced after common.ps1.
function Invoke-AfRole {
    [CmdletBinding()]
    param(
        [string]$ProjectPath, [string]$Role, [string]$Prompt,
        [string]$CodexCommand = 'codex', [string]$Model,
        [int]$TimeoutSeconds = 900
    )
    $schemaName = switch ($Role) {
        'implementer' { 'implementation' }
        { $_ -in @('tester', 'reviewer', 'security') } { 'review' }
        default { $Role }
    }
    $schema = Join-Path $ProjectPath "automation/schemas/$schemaName.schema.json"
    $instructions = Get-Content -LiteralPath (Join-Path $ProjectPath "automation/prompts/$Role.md") -Raw
    $runId = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfff') + '-' + [guid]::NewGuid().ToString('N').Substring(0, 8)
    $runDir = Join-Path $ProjectPath ".agent-factory/runs/$runId"
    [void][IO.Directory]::CreateDirectory($runDir)
    $output = Join-Path $runDir "$Role.json"
    $isImplementer = $Role -eq 'implementer'
    $sandbox = if ($isImplementer) { 'workspace-write' } else { 'read-only' }
    $approval = if ($isImplementer) { 'on-request' } else { 'never' }
    # A JSON string is also a valid TOML basic string for these checked-in instructions.
    $encodedInstructions = ConvertTo-Json -InputObject $instructions -Compress
    $cliArgs = @('-a', $approval, 'exec', '--ignore-user-config', '--ephemeral', '--sandbox', $sandbox,
        '-C', $ProjectPath, '--output-schema', $schema, '--output-last-message', $output, '--json')
    if ($isImplementer) { $cliArgs += @('-c', 'approvals_reviewer="auto_review"') }
    $cliArgs += @('-c', "developer_instructions=$encodedInstructions")
    if ($Model) { $cliArgs += @('--model', $Model) }
    $cliArgs += '-'
    $result = Invoke-AfProcess -File $CodexCommand -Arguments $cliArgs -WorkingDirectory $ProjectPath `
        -LogPath (Join-Path $runDir "$Role.log") -InputText $Prompt -TimeoutSeconds $TimeoutSeconds
    if ($result.exit_code -ne 0 -or $result.timed_out) { throw "Codex $Role failed (exit $($result.exit_code)); inspect $runDir" }
    if (-not (Test-Path -LiteralPath $output -PathType Leaf)) { throw "Codex $Role produced no final response: $output" }
    $json = Get-Content -LiteralPath $output -Raw
    if (-not (Test-Json -Json $json -SchemaFile $schema -ErrorAction Stop)) { throw "Codex $Role response failed schema validation." }
    return (Read-AfJson -Path $output)
}

function Invoke-AfReviews {
    param([string]$ProjectPath, [string]$Prompt, [string]$CodexCommand, [string]$Model, [int]$TimeoutSeconds)
    $libraryDirectory = $PSScriptRoot
    return @(@('tester', 'reviewer', 'security') | ForEach-Object -Parallel {
        . (Join-Path $using:libraryDirectory 'common.ps1')
        . (Join-Path $using:libraryDirectory 'codex.ps1')
        $roleName = $_
        try {
            $reply = Invoke-AfRole -ProjectPath $using:ProjectPath -Role $roleName -Prompt $using:Prompt `
                -CodexCommand $using:CodexCommand -Model $using:Model -TimeoutSeconds $using:TimeoutSeconds
            @{ role = $roleName; response = $reply; error = $null }
        }
        catch { @{ role = $roleName; response = $null; error = $_.Exception.Message } }
    } -ThrottleLimit 3)
}
