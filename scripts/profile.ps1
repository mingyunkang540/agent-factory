#requires -Version 7.4
# Dot-source this file for the current session. It never edits $PROFILE.
$global:AgentFactoryRuntimeDirectory = $PSScriptRoot
if (Test-Path -LiteralPath (Join-Path (Split-Path $PSScriptRoot -Parent) 'presets') -PathType Container) {
    $global:AgentFactoryRoot = Split-Path $PSScriptRoot -Parent
    function global:ai-new { & (Join-Path $global:AgentFactoryRoot 'scripts/new-app.ps1') @args }
}
function global:ai-init { & (Join-Path $global:AgentFactoryRuntimeDirectory 'agent.ps1') init @args }
function global:ai-next { & (Join-Path $global:AgentFactoryRuntimeDirectory 'agent.ps1') next @args }
function global:ai-run { & (Join-Path $global:AgentFactoryRuntimeDirectory 'agent.ps1') run @args }
function global:ai-check { & (Join-Path $global:AgentFactoryRuntimeDirectory 'quality.ps1') @args }
function global:ai-status { & (Join-Path $global:AgentFactoryRuntimeDirectory 'agent.ps1') status @args }
function global:ai-pr { & (Join-Path $global:AgentFactoryRuntimeDirectory 'agent.ps1') pr @args }
function global:ai-release { & (Join-Path $global:AgentFactoryRuntimeDirectory 'agent.ps1') release @args }
function global:ai-approve { & (Join-Path $global:AgentFactoryRuntimeDirectory 'agent.ps1') approve @args }
function global:ai-resume { & (Join-Path $global:AgentFactoryRuntimeDirectory 'agent.ps1') resume @args }
function global:ai-review { & (Join-Path $global:AgentFactoryRuntimeDirectory 'agent.ps1') review @args }
