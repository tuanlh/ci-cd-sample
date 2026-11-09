$ErrorActionPreference = 'Stop'
Push-Location (Join-Path $PSScriptRoot '..')
try {
    docker info --format '{{.ServerVersion}}'
    if ($LASTEXITCODE -ne 0) { throw 'Start Docker Desktop (Linux containers) first.' }
    docker compose --profile test run --build --rm tests
    if ($LASTEXITCODE -ne 0) { throw 'Tests failed. Application was not rebuilt.' }
    docker compose up -d --build api
    if ($LASTEXITCODE -ne 0) { throw 'Container build/start failed.' }
    & "$PSScriptRoot/smoke.ps1" -ExpectedVersion 'local'
} finally { Pop-Location }
