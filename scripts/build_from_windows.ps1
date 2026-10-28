[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$')]
    [string]$Repository,
    [string]$Ref = 'main',
    [string]$OutputDirectory = (Join-Path $PSScriptRoot '..\downloads')
)
$ErrorActionPreference = 'Stop'
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw 'Installare GitHub CLI da https://cli.github.com/ e autorizzarlo localmente con gh auth login.'
}
& gh auth status
if ($LASTEXITCODE -ne 0) { throw 'Accesso GitHub CLI non autorizzato. Eseguire gh auth login personalmente.' }

$correlation = [guid]::NewGuid().ToString('N')
$workflow = 'build-ipad-unsigned.yml'
& gh workflow run $workflow --repo $Repository --ref $Ref -f "request_id=$correlation"
if ($LASTEXITCODE -ne 0) { throw 'Avvio workflow fallito: verificare repo, branch, permesso Actions write e workflow nel branch predefinito.' }

$run = $null
$deadline = [DateTime]::UtcNow.AddMinutes(3)
while ([DateTime]::UtcNow -lt $deadline -and $null -eq $run) {
    $json = & gh run list --repo $Repository --workflow $workflow --event workflow_dispatch --limit 100 --json databaseId,displayTitle,headSha,url
    if ($LASTEXITCODE -ne 0) { throw 'Impossibile leggere le esecuzioni GitHub Actions.' }
    $candidates = @(($json -join "`n") | ConvertFrom-Json | Where-Object { $_.displayTitle -eq "Atelier unsigned $correlation" })
    if ($candidates.Count -gt 1) { throw 'Token di correlazione duplicato; interrompo per non scaricare una build diversa.' }
    if ($candidates.Count -eq 1) { $run = $candidates[0] } else { Start-Sleep -Seconds 3 }
}
if ($null -eq $run) { throw "Workflow inviato ma ID non trovato. Aprire https://github.com/$Repository/actions e cercare $correlation." }
Write-Host "Build commit $($run.headSha): $($run.url)"
& gh run watch $run.databaseId --repo $Repository --exit-status
$workflowExit = $LASTEXITCODE
$downloadPath = [IO.Path]::GetFullPath((Join-Path $OutputDirectory ([string]$run.databaseId)))
New-Item -ItemType Directory -Path $downloadPath -Force | Out-Null
& gh run download $run.databaseId --repo $Repository --name Atelier-unsigned --dir $downloadPath
if ($LASTEXITCODE -ne 0) {
    throw "Artefatto IPA non disponibile; build o verifiche non riuscite. Log: $($run.url)"
}
$ipa = Join-Path $downloadPath 'Atelier-unsigned.ipa'
$reportPath = Join-Path $downloadPath 'ipa-verification.json'
$buildReportPath = Join-Path $downloadPath 'BUILD_REPORT.json'
if (-not (Test-Path -LiteralPath $ipa) -or -not (Test-Path -LiteralPath $reportPath) -or -not (Test-Path -LiteralPath $buildReportPath)) {
    throw 'Download incompleto: IPA o rapporti di verifica assenti.'
}
$report = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
$buildReport = Get-Content -LiteralPath $buildReportPath -Raw | ConvertFrom-Json
if ($buildReport.commit -ne $run.headSha) { throw 'Il commit del rapporto non corrisponde al workflow richiesto.' }
$actual = (Get-FileHash -LiteralPath $ipa -Algorithm SHA256).Hash.ToLowerInvariant()
if ($report.result -ne 'passed' -or $actual -ne $report.sha256) { throw 'SHA-256 o validazione CI non corrispondenti.' }
Write-Host "IPA unsigned verificata: $ipa"
Write-Host "SHA-256: $actual"
if ($workflowExit -ne 0) {
    throw "IPA device prodotta e verificata, ma workflow non riuscito (per esempio test simulatore). Consultare $($run.url)."
}
Write-Host 'Workflow riuscito. Firma e prove su iPad restano passaggi separati.'
