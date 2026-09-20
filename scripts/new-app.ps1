#requires -Version 7.4
[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)][string]$Name,
    [ValidateSet('react-web', 'react-capacitor', 'toss-miniapp', 'unity')][string]$Preset = 'react-web',
    [string]$Destination = '.',
    [switch]$NoGit
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')

function Copy-FactoryTree([string]$Source, [string]$Target) {
    [void][IO.Directory]::CreateDirectory($Target)
    foreach ($entry in Get-ChildItem -LiteralPath $Source -Force) {
        if ($entry.Name -in @('node_modules', 'dist', '.git', 'coverage', '.agent-factory')) { continue }
        if ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Symlinks are not copied: $($entry.FullName)" }
        $output = Join-Path $Target $entry.Name
        if ($entry.PSIsContainer) { Copy-FactoryTree $entry.FullName $output }
        else { Copy-Item -LiteralPath $entry.FullName -Destination $output }
    }
}

try {
    if ($Name -cnotmatch '^[a-z][a-z0-9-]{0,62}$' -or $Name -match '-$' -or $Name -match '^(con|prn|aux|nul|com[0-9]|lpt[0-9])$') {
        throw 'Name must be a lowercase kebab-case identifier (1–63 characters), not a Windows reserved name.'
    }
    $factoryRoot = Split-Path $PSScriptRoot -Parent
    if (-not (Test-Path -LiteralPath (Join-Path $factoryRoot 'template') -PathType Container)) {
        throw 'new-app must run from the original Agent Factory repository; generated apps include only the project runtime.'
    }
    $presetRoot = Join-Path $factoryRoot "presets/$Preset"
    $manifest = Read-AfJson (Join-Path $presetRoot 'preset.json')
    if (-not $manifest.supported) { throw "Preset '$Preset' is an extension stub, not supported in v0.1." }
    $parent = [IO.Path]::GetFullPath($Destination, (Get-Location).Path)
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) { throw "Destination parent does not exist: $parent" }
    $target = Join-Path $parent $Name
    if (Test-Path -LiteralPath $target) { throw "Refusing to overwrite an existing destination: $target" }
    if (-not $NoGit) { [void](Get-Command git -CommandType Application -ErrorAction Stop) }
    # Atomic directory creation refuses both a prior directory and a concurrent creator.
    $claimPath = Join-Path $parent ".$Name.factory-create.lock"
    $claim = [IO.File]::Open($claimPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try {
        if (Test-Path -LiteralPath $target) { throw "Destination appeared during creation: $target" }
        [void][IO.Directory]::CreateDirectory($target)
        Copy-FactoryTree (Join-Path $factoryRoot 'template') $target
        if ($manifest.ContainsKey('base') -and $manifest.base) {
            if ($manifest.base -ne 'react-web' -or $Preset -ne 'react-capacitor') { throw 'Unsupported preset inheritance.' }
            Copy-FactoryTree (Join-Path $factoryRoot 'presets/react-web/files') $target
        }
        Copy-FactoryTree (Join-Path $presetRoot 'files') $target
        Copy-FactoryTree $PSScriptRoot (Join-Path $target 'automation/scripts')
        $version = (Get-Content -LiteralPath (Join-Path $factoryRoot 'VERSION') -Raw).Trim()
        foreach ($file in Get-ChildItem -LiteralPath $target -File -Recurse -Force) {
            if ($file.Extension -notin @('.md', '.json', '.toml', '.ts', '.tsx', '.yml', '.yaml', '.html', '.css')) { continue }
            $body = [IO.File]::ReadAllText($file.FullName)
            $replaced = $body.Replace('{{PROJECT_NAME}}', $Name).Replace('{{PRESET}}', $Preset).Replace('{{FACTORY_VERSION}}', $version).Replace('{{APP_ID_SUFFIX}}', $Name.Replace('-', ''))
            if ($body -cne $replaced) { [IO.File]::WriteAllText($file.FullName, $replaced, [Text.UTF8Encoding]::new($false)) }
        }
        Write-AfJson -Path (Join-Path $target 'agent-factory.json') -Value ([ordered]@{
            schema_version = 1; project = $Name; preset = $Preset; agent_factory_version = $version
            max_attempts = 3; max_tasks_per_run = 5; commands = $manifest.commands
        })
        Write-AfJson -Path (Join-Path $target 'docs/STATUS.json') -Value (New-AfStatus)
        if (-not $NoGit) {
            $git = Invoke-AfProcess -File 'git' -Arguments @('init', '--initial-branch=main') -WorkingDirectory $target -LogPath (Join-Path $target '.agent-factory/logs/git-init.log')
            if ($git.exit_code -ne 0) { throw "Git initialization failed. Files retained at $target. See .agent-factory/logs/git-init.log." }
        }
        Write-Host "Created $target (Factory $version, $Preset)."
        Write-Host 'Next: edit IDEA.md, run npm ci, then automation/scripts/agent.ps1 init.'
    }
    finally {
        $claim.Dispose()
        Remove-Item -LiteralPath $claimPath -ErrorAction SilentlyContinue
    }
    exit 0
}
catch { Write-Error -Message $_.Exception.Message -ErrorAction Continue; exit 2 }
