# Phase 3 leaderboard smoke: device auth -> submit_match_result(ranked) -> leaderboard_top
# Run from server/: .\scripts\smoke_leaderboard.ps1

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

Write-Host "=== Goofy Balls leaderboard smoke ===" -ForegroundColor Cyan

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
$submitFile = Join-Path $tmp "submit_rpc.json"
$topFile = Join-Path $tmp "top_rpc.json"

$deviceId = "smoke_lb_" + [guid]::NewGuid().ToString("N").Substring(0, 12)
Set-Content -Path $authFile -Value "{`"id`":`"$deviceId`"}" -Encoding ascii -NoNewline

$authOut = & curl.exe -s -u "${serverKey}:" -H "Content-Type: application/json" --data-binary "@$authFile" "http://127.0.0.1:7350/v2/account/authenticate/device?create=true"
$auth = $authOut | ConvertFrom-Json
if (-not $auth.token) {
	Write-Error "No session token: $authOut"
}
Write-Host "[1/3] auth ok" -ForegroundColor Green
$token = $auth.token

$innerSubmit = "{`"mode`":`"ranked`",`"winner_side`":0,`"local_side`":0,`"score_left`":5,`"score_right`":3}"
$rpcSubmit = ($innerSubmit | ConvertTo-Json -Compress)
Set-Content -Path $submitFile -Value $rpcSubmit -Encoding ascii -NoNewline

Write-Host "[2/3] submit_match_result (ranked win)"
$submitOut = & curl.exe -s -H "Authorization: Bearer $token" -H "Content-Type: application/json" --data-binary "@$submitFile" "http://127.0.0.1:7350/v2/rpc/submit_match_result?unwrap"
Write-Host $submitOut -ForegroundColor Green
$submitted = $submitOut | ConvertFrom-Json
if (-not $submitted.ok) {
	docker compose logs --tail 40 nakama
	Write-Error "submit_match_result failed: $submitOut"
}
if (-not $submitted.board_updated) {
	Write-Error "expected board_updated=true for ranked win"
}
if ($submitted.progress.wins_ranked -lt 1) {
	Write-Error "wins_ranked not incremented"
}

Start-Sleep -Seconds 2

$innerTop = "{`"limit`":10}"
$rpcTop = ($innerTop | ConvertTo-Json -Compress)
Set-Content -Path $topFile -Value $rpcTop -Encoding ascii -NoNewline

Write-Host "[3/3] leaderboard_top"
$topOut = & curl.exe -s -H "Authorization: Bearer $token" -H "Content-Type: application/json" --data-binary "@$topFile" "http://127.0.0.1:7350/v2/rpc/leaderboard_top?unwrap"
Write-Host $topOut -ForegroundColor Green
$top = $topOut | ConvertFrom-Json
if (-not $top.ok) {
	Write-Error "leaderboard_top failed: $topOut"
}
if ($null -eq $top.records -or $top.records.Count -lt 1) {
	Write-Error "leaderboard_top returned no records"
}

Write-Host "`nLeaderboard smoke OK" -ForegroundColor Cyan
