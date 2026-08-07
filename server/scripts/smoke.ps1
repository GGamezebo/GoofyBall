# Phase 0 smoke: Postgres healthy + Nakama healthcheck + HTTP API reachable.
# Run from repo:  .\server\scripts\smoke.ps1
# Or from server/: .\scripts\smoke.ps1

$ErrorActionPreference = "Stop"

$ServerDir = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $ServerDir

Write-Host "=== Goofy Balls server smoke ===" -ForegroundColor Cyan
Write-Host "Directory: $ServerDir"

if (-not (Test-Path (Join-Path $ServerDir ".env"))) {
	Write-Error "Missing server/.env - copy .env.example to .env first."
}

Write-Host "`n[1/4] docker compose ps"
docker compose ps
if ($LASTEXITCODE -ne 0) {
	Write-Error "docker compose ps failed. Is Docker Desktop running?"
}

function Get-ContainerHealth([string]$Name) {
	# Avoid 2>$null with native docker - PowerShell can swallow stdout too.
	$output = & docker inspect --format "{{.State.Health.Status}}" $Name
	if ($LASTEXITCODE -ne 0) {
		return ""
	}
	return ("$output").Trim()
}

Write-Host "`n[2/4] Postgres health"
$pg = Get-ContainerHealth "goofyballs-postgres"
if ($pg -ne "healthy") {
	Write-Error "Postgres not healthy (status='$pg'). Try: docker compose up -d ; docker compose logs postgres"
}
Write-Host "postgres: $pg" -ForegroundColor Green

Write-Host "`n[3/4] Nakama container healthcheck"
$nk = Get-ContainerHealth "goofyballs-nakama"
if ($nk -ne "healthy") {
	Write-Host "nakama status='$nk' - waiting up to 60s..." -ForegroundColor Yellow
	$deadline = (Get-Date).AddSeconds(60)
	do {
		Start-Sleep -Seconds 3
		$nk = Get-ContainerHealth "goofyballs-nakama"
		if ($nk -eq "healthy") { break }
	} while ((Get-Date) -lt $deadline)
}
if ($nk -ne "healthy") {
	docker compose logs --tail 80 nakama
	Write-Error "Nakama not healthy (status='$nk')."
}
Write-Host "nakama: $nk" -ForegroundColor Green

Write-Host "`n[4/4] HTTP API (7350) + Console (7351)"
try {
	$api = Invoke-WebRequest -Uri "http://127.0.0.1:7350/" -UseBasicParsing -TimeoutSec 10
	Write-Host "API 7350 -> HTTP $($api.StatusCode)" -ForegroundColor Green
} catch {
	Write-Error "API http://127.0.0.1:7350/ failed: $_"
}

try {
	$console = Invoke-WebRequest -Uri "http://127.0.0.1:7351/" -UseBasicParsing -TimeoutSec 10
	Write-Host "Console 7351 -> HTTP $($console.StatusCode)" -ForegroundColor Green
} catch {
	Write-Error "Console http://127.0.0.1:7351/ failed: $_"
}

Write-Host "`nSmoke OK. Console: http://127.0.0.1:7351/" -ForegroundColor Cyan
