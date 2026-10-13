# PT-PHONE dev tool (not shipped). Draw-call attribution on the Compatibility renderer: hides each
# canvas child under <Path> in turn (depth levels deep) and prints the draw calls the frame loses.
#   pwsh tools/dev/perf_scan.ps1 -Path "Main/Player" -Depth 3 [-Alive 10] [-Wave 1] [-Project <dir>]
param(
	[string]$Path = "",
	[int]$Depth = 1,
	[int]$Alive = 10,
	[int]$Wave = 1,
	[string]$Project = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
)
$godot = "D:\godot\Godot_v4.7.1-stable_win64_console.exe"
$profileDir = Join-Path $env:TEMP ("hc_scan_" + [guid]::NewGuid().ToString("N").Substring(0, 8))
New-Item -ItemType Directory -Force $profileDir | Out-Null
$out = & $godot --path $Project --audio-driver Dummy --no-focus-pause --rendering-method gl_compatibility --rendering-driver opengl3 --fixed-fps 60 -s res://src/dev/swarm_probe.gd -- --probe=perf "--alive=$Alive" "--start-wave=$Wave" --frames=3000 --warmup=240 --mobile "--toggle=scan:$Path@$Depth" "--meta-profile-dir=$profileDir" 2>&1 | Out-String
($out -split "`n" | Where-Object { $_ -match "^SCAN|SCRIPT ERROR|Parse Error" }) -join "`n"
