# Phase 4 rooms smoke: auth A create -> auth B join -> A close
# Run from server/: .\scripts\smoke_rooms.ps1

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
	$rpcFile = Join-Path $env:TEMP ("goofy_rpc_" + $RpcId + ".json")
	$wrapped = ($InnerJson | ConvertTo-Json -Compress)
	Set-Content -Path $rpcFile -Value $wrapped -Encoding ascii -NoNewline
	return & curl.exe -s -H "Authorization: Bearer $Token" -H "Content-Type: application/json" --data-binary "@$rpcFile" "http://127.0.0.1:7350/v2/rpc/${RpcId}?unwrap"
}

Write-Host "=== Goofy Balls rooms smoke ===" -ForegroundColor Cyan

if (-not (Test-Path (Join-Path $ServerDir ".env"))) {
	Write-Error "Missing server/.env"
}
$envMap = Read-DotEnv (Join-Path $ServerDir ".env")
$serverKey = $envMap["NAKAMA_SERVER_KEY"]
if ([string]::IsNullOrWhiteSpace($serverKey)) {
	Write-Error "NAKAMA_SERVER_KEY missing in .env"
}

$tokenA = Auth-Device $serverKey ("smoke_room_a_" + [guid]::NewGuid().ToString("N").Substring(0, 8))
Write-Host "[1/4] host auth ok" -ForegroundColor Green

$createOut = Invoke-Rpc $tokenA "room_create" "{`"region`":`"eu`"}"
Write-Host $createOut
$created = $createOut | ConvertFrom-Json
if (-not $created.ok -or [string]::IsNullOrWhiteSpace($created.code) -or [string]::IsNullOrWhiteSpace($created.match_name)) {
	docker compose logs --tail 40 nakama
	Write-Error "room_create failed: $createOut"
}
Write-Host "[2/4] room_create ok code=$($created.code) match_name=$($created.match_name)" -ForegroundColor Green

$tokenB = Auth-Device $serverKey ("smoke_room_b_" + [guid]::NewGuid().ToString("N").Substring(0, 8))
$joinInner = "{`"code`":`"$($created.code.ToLower())`"}"
$joinOut = Invoke-Rpc $tokenB "room_join" $joinInner
Write-Host $joinOut
$joined = $joinOut | ConvertFrom-Json
if (-not $joined.ok) {
	Write-Error "room_join failed: $joinOut"
}
if ($joined.match_name -ne $created.match_name -and $joined.match_id -ne $created.match_id) {
	Write-Error "join match_name mismatch"
}
Write-Host "[3/4] room_join ok (case-insensitive)" -ForegroundColor Green

$closeOut = Invoke-Rpc $tokenA "room_close" "{`"code`":`"$($created.code)`"}"
Write-Host $closeOut
$closed = $closeOut | ConvertFrom-Json
if (-not $closed.ok) {
	Write-Error "room_close failed: $closeOut"
}
Write-Host "[4/4] room_close ok" -ForegroundColor Green

Write-Host "`nRooms smoke OK" -ForegroundColor Cyan
