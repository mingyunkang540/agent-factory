# A detached child keeps the redirected output pipe open after this parent exits.
$childInfo=[Diagnostics.ProcessStartInfo]::new()
$childInfo.FileName=(Get-Command pwsh -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
$childInfo.UseShellExecute=$false
$childInfo.CreateNoWindow=$true
$childInfo.WorkingDirectory=$PSScriptRoot
foreach ($argument in @('-NoProfile','-NonInteractive','-Command','Start-Sleep -Seconds 4')) { $childInfo.ArgumentList.Add($argument) }
[Diagnostics.Process]::Start($childInfo) | Out-Null
exit 0
