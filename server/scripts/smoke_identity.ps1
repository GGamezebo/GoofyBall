# Phase 1 identity smoke: device auth -> health_ext -> get_account_view
# Run from server/: .\scripts\smoke_identity.ps1

$ErrorActionPreference = "Stop"

$ServerDir = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $ServerDir

function Read-DotEnv([string]$Path) {
	$map = @{}
	Get-Content $Path | ForEach-Object {
		$line = $_.Trim()
		if ($line -eq "" -or $line.StartsWith("#")) { return }
		$i = $line.IndexOf("=")
		if ($i -lt 1) { return }
		$map[$line.Substring(0, $i)] = $line.Substring($i + 1)
	}
	return $map
}

Write-Host "=== Goofy Balls identity smoke ===" -ForegroundColor Cyan

if (-not (Test-Path (Join-Path $ServerDir ".env"))) {
	Write-Error "Missing server/.env"
}

$envMap = Read-DotEnv (Join-Path $ServerDir ".env")
$serverKey = $envMap["NAKAMA_SERVER_KEY"]
if ([string]::IsNullOrWhiteSpace($serverKey)) {
	Write-Error "NAKAMA_SERVER_KEY missing in .env"
}

$basic = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("${serverKey}:"))
$deviceId = "smoke_device_" + [guid]::NewGuid().ToString("N").Substring(0, 16)

Write-Host "`n[1/3] authenticate device ($deviceId)"
$authHeaders = @{
	Authorization = "Basic $basic"
	"Content-Type" = "application/json"
}
$authBody = (@{ id = $deviceId } | ConvertTo-Json -Compress)
$auth = Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:7350/v2/account/authenticate/device?create=true" -Headers $authHeaders -Body $authBody
if (-not $auth.token) {
	Write-Error "No session token returned"
}
Write-Host "token ok" -ForegroundColor Green

$sessionHeaders = @{
	Authorization = "Bearer $($auth.token)"
	"Content-Type" = "application/json"
}

Write-Host "`n[2/3] rpc health_ext"
# Nakama RPC body is a JSON-encoded string payload.
$rpcBody = '"{}"'
$health = Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:7350/v2/rpc/health_ext?unwrap" -Headers $sessionHeaders -Body $rpcBody
Write-Host ($health | ConvertTo-Json -Compress) -ForegroundColor Green
if (-not $health.ok) {
	Write-Error "health_ext.ok != true (is identity.js loaded? restart nakama)"
}

Write-Host "`n[3/3] rpc get_account_view"
$view = Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:7350/v2/rpc/get_account_view?unwrap" -Headers $sessionHeaders -Body $rpcBody
Write-Host ($view | ConvertTo-Json -Compress) -ForegroundColor Green
if (-not $view.user_id) {
	Write-Error "get_account_view missing user_id"
}

Write-Host "`nIdentity smoke OK. user_id=$($view.user_id)" -ForegroundColor Cyan
