# Phase 4 matchmaker smoke: A waits -> B matches -> A status matched
# Run from server/: .\scripts\smoke_matchmaker.ps1

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

function Auth-Device([string]$ServerKey, [string]$DeviceId) {
	$authFile = Join-Path $env:TEMP ("goofy_auth_" + $DeviceId + ".json")
	Set-Content -Path $authFile -Value "{`"id`":`"$DeviceId`"}" -Encoding ascii -NoNewline
	$authOut = & curl.exe -s -u "${ServerKey}:" -H "Content-Type: application/json" --data-binary "@$authFile" "http://127.0.0.1:7350/v2/account/authenticate/device?create=true"
	$auth = $authOut | ConvertFrom-Json
	if (-not $auth.token) {
		Write-Error "Auth failed for $DeviceId : $authOut"
	}
	return $auth.token
}

function Invoke-Rpc([string]$Token, [string]$RpcId, [string]$InnerJson) {
	$rpcFile = Join-Path $env:TEMP ("goofy_rpc_" + $RpcId + "_" + [guid]::NewGuid().ToString("N").Substring(0, 6) + ".json")
	$wrapped = ($InnerJson | ConvertTo-Json -Compress)
	Set-Content -Path $rpcFile -Value $wrapped -Encoding ascii -NoNewline
	return & curl.exe -s -H "Authorization: Bearer $Token" -H "Content-Type: application/json" --data-binary "@$rpcFile" "http://127.0.0.1:7350/v2/rpc/${RpcId}?unwrap"
}

Write-Host "=== Goofy Balls matchmaker smoke ===" -ForegroundColor Cyan

if (-not (Test-Path (Join-Path $ServerDir ".env"))) {
	Write-Error "Missing server/.env"
}
$envMap = Read-DotEnv (Join-Path $ServerDir ".env")
$serverKey = $envMap["NAKAMA_SERVER_KEY"]
if ([string]::IsNullOrWhiteSpace($serverKey)) {
	Write-Error "NAKAMA_SERVER_KEY missing in .env"
}

$region = "smoke_" + [guid]::NewGuid().ToString("N").Substring(0, 6)
$tokenA = Auth-Device $serverKey ("smoke_mm_a_" + [guid]::NewGuid().ToString("N").Substring(0, 8))
$tokenB = Auth-Device $serverKey ("smoke_mm_b_" + [guid]::NewGuid().ToString("N").Substring(0, 8))
Write-Host "[1/4] two guests auth ok region=$region" -ForegroundColor Green

$enqA = Invoke-Rpc $tokenA "mm_enqueue" "{`"skill`":100,`"region`":`"$region`"}"
Write-Host $enqA
$waitA = $enqA | ConvertFrom-Json
if (-not $waitA.ok -or $waitA.status -ne "waiting") {
	docker compose logs --tail 40 nakama
	Write-Error "A expected waiting: $enqA"
}
Write-Host "[2/4] A waiting ticket=$($waitA.ticket_id)" -ForegroundColor Green

$enqB = Invoke-Rpc $tokenB "mm_enqueue" "{`"skill`":120,`"region`":`"$region`"}"
Write-Host $enqB
$matchB = $enqB | ConvertFrom-Json
if (-not $matchB.ok -or $matchB.status -ne "matched" -or [string]::IsNullOrWhiteSpace($matchB.match_name)) {
	docker compose logs --tail 40 nakama
	Write-Error "B expected matched: $enqB"
}
Write-Host "[3/4] B matched match_name=$($matchB.match_name)" -ForegroundColor Green

$statusA = Invoke-Rpc $tokenA "mm_status" "{`"ticket_id`":`"$($waitA.ticket_id)`"}"
Write-Host $statusA
$stA = $statusA | ConvertFrom-Json
if (-not $stA.ok -or $stA.status -ne "matched") {
	Write-Error "A status expected matched: $statusA"
}
if ($stA.match_name -ne $matchB.match_name -and $stA.match_id -ne $matchB.match_id) {
	Write-Error "A/B match_name mismatch"
}
Write-Host "[4/4] A status matched same match" -ForegroundColor Green

Write-Host "`nMatchmaker smoke OK" -ForegroundColor Cyan
