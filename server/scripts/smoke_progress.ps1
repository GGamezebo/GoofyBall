# Phase 2 progress smoke: device auth -> progress_merge -> progress_pull
# Run from server/: .\scripts\smoke_progress.ps1

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

Write-Host "=== Goofy Balls progress smoke ===" -ForegroundColor Cyan

if (-not (Test-Path (Join-Path $ServerDir ".env"))) {
	Write-Error "Missing server/.env"
}

$envMap = Read-DotEnv (Join-Path $ServerDir ".env")
$serverKey = $envMap["NAKAMA_SERVER_KEY"]
if ([string]::IsNullOrWhiteSpace($serverKey)) {
	Write-Error "NAKAMA_SERVER_KEY missing in .env"
}

$tmp = Join-Path $env:TEMP "goofyballs_smoke"
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
$authFile = Join-Path $tmp "auth.json"
$rpcFile = Join-Path $tmp "rpc_body.json"
$emptyRpc = Join-Path $tmp "empty_rpc.json"

$deviceId = "smoke_progress_" + [guid]::NewGuid().ToString("N").Substring(0, 12)
Set-Content -Path $authFile -Value "{`"id`":`"$deviceId`"}" -Encoding ascii -NoNewline

$authOut = & curl.exe -s -u "${serverKey}:" -H "Content-Type: application/json" --data-binary "@$authFile" "http://127.0.0.1:7350/v2/account/authenticate/device?create=true"
$auth = $authOut | ConvertFrom-Json
if (-not $auth.token) {
	Write-Error "No session token: $authOut"
}
Write-Host "[1/3] auth ok" -ForegroundColor Green
$token = $auth.token

$ts = [int][double]::Parse((Get-Date -UFormat %s))
# Nakama RPC body must be a JSON *string* whose contents are the payload object.
$inner = "{`"progress`":{`"schema_version`":1,`"updated_at`":$ts,`"matches_played`":3,`"wins_two_player`":1,`"wins_vs_ai`":2,`"losses_vs_ai`":0}}"
$rpcWrapped = ($inner | ConvertTo-Json -Compress)
# ConvertTo-Json on a string wraps/escapes it for us.
Set-Content -Path $rpcFile -Value $rpcWrapped -Encoding ascii -NoNewline
Set-Content -Path $emptyRpc -Value '"{}"' -Encoding ascii -NoNewline

Write-Host "[2/3] progress_merge"
$mergeOut = & curl.exe -s -H "Authorization: Bearer $token" -H "Content-Type: application/json" --data-binary "@$rpcFile" "http://127.0.0.1:7350/v2/rpc/progress_merge?unwrap"
Write-Host $mergeOut -ForegroundColor Green
$merged = $mergeOut | ConvertFrom-Json
if (-not $merged.ok) {
	Write-Error "progress_merge failed: $mergeOut"
}
if ($merged.progress.matches_played -lt 3) {
	docker compose logs --tail 25 nakama
	Write-Error "merge did not keep matches_played"
}

Write-Host "[3/3] progress_pull"
$pullOut = & curl.exe -s -H "Authorization: Bearer $token" -H "Content-Type: application/json" --data-binary "@$emptyRpc" "http://127.0.0.1:7350/v2/rpc/progress_pull?unwrap"
Write-Host $pullOut -ForegroundColor Green
$pulled = $pullOut | ConvertFrom-Json
if (-not $pulled.exists) {
	Write-Error "progress_pull exists=false after merge"
}
if ($pulled.progress.wins_vs_ai -lt 2) {
	Write-Error "pulled wins_vs_ai mismatch"
}

Write-Host "`nProgress smoke OK" -ForegroundColor Cyan
