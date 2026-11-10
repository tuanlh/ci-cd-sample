param(
    [string]$Image = 'ghcr.io/tuanlh/ci-cd-sample:89f870f0e352d4bc38db93aec5b6d230531471e7',
    [string]$ExpectedVersion = '',
    [ValidateRange(1, 65535)]
    [int]$Port = 18080
)
$ErrorActionPreference = 'Stop'

if (-not $ExpectedVersion) {
    if ($Image -notmatch ':([a-f0-9]{40})$') {
        throw 'Pass -ExpectedVersion with the full commit SHA when the image tag is not a commit SHA.'
    }
    $ExpectedVersion = $Matches[1]
}

docker pull $Image
if ($LASTEXITCODE -ne 0) { throw "Could not pull $Image. Check Docker and GHCR read access." }

$containerId = docker run -d --rm -p "127.0.0.1:${Port}:8080" $Image
if ($LASTEXITCODE -ne 0) { throw "Could not start the release container on port $Port." }

try {
    & "$PSScriptRoot/smoke.ps1" -BaseUrl "http://127.0.0.1:$Port" -ExpectedVersion $ExpectedVersion
} catch {
    docker logs --tail 50 $containerId
    throw
} finally {
    docker stop $containerId | Out-Null
    if ($LASTEXITCODE -ne 0) { Write-Warning "Could not stop container $containerId. Check docker ps." }
}
