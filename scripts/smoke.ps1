param(
    [string]$BaseUrl = 'http://localhost:8080',
    [string]$ExpectedVersion = '',
    [int]$Attempts = 30
)
$ErrorActionPreference = 'Stop'
$BaseUrl = $BaseUrl.TrimEnd('/')
$ready = $false
for ($i = 0; $i -lt $Attempts; $i++) {
    try {
        $health = Invoke-RestMethod "$BaseUrl/health" -TimeoutSec 3
        if ($health.status -eq 'healthy') { $ready = $true; break }
    } catch { }
    Start-Sleep -Seconds 2
}
if (-not $ready) { throw "Health check failed: $BaseUrl" }
$version = Invoke-RestMethod "$BaseUrl/version" -TimeoutSec 5
if ($ExpectedVersion -and $version.version -ne $ExpectedVersion) {
    throw "Wrong version: expected $ExpectedVersion, got $($version.version)"
}
$body = @{ title = 'Smoke test CI/CD' } | ConvertTo-Json
$response = Invoke-WebRequest "$BaseUrl/tasks" -Method Post -ContentType 'application/json' -Body $body -TimeoutSec 5 -UseBasicParsing
if ([int]$response.StatusCode -ne 201) { throw 'Expected HTTP 201' }
$task = $response.Content | ConvertFrom-Json
$read = Invoke-RestMethod "$BaseUrl/tasks/$($task.id)" -TimeoutSec 5
if ($read.title -ne 'Smoke test CI/CD' -or $read.isCompleted) { throw 'Created task is incorrect' }
$completed = Invoke-RestMethod "$BaseUrl/tasks/$($task.id)/complete" -Method Put -TimeoutSec 5
if (-not $completed.isCompleted) { throw 'Complete task failed' }
try {
    Invoke-RestMethod "$BaseUrl/tasks" -Method Post -ContentType 'application/json' -Body '{"title":" "}' -TimeoutSec 5 | Out-Null
    throw 'Expected HTTP 400 for blank title'
} catch {
    if (-not $_.Exception.Response -or [int]$_.Exception.Response.StatusCode -ne 400) { throw }
}
Write-Host "PASS: health, version=$($version.version), create/read/complete, validation 400" -ForegroundColor Green
