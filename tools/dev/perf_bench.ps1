# PT-PHONE dev tool (not shipped). One swarm_probe perf run -> one parsed result line.
#
#   pwsh tools/dev/perf_bench.ps1 -Mode compat -Alive 180 [-Project <dir>] [-Hz 30] [-Wave 10]
#
# Modes: headless | fwd (Forward+ windowed) | compat (Compatibility/OpenGL3 windowed, the phone
# renderer). -Mobile adds the phone caps and LOD (the 180 cap). Windowed modes need a desktop session.
# Output: MODE alive draw_calls median mean p95 max (ms) and the sim split, as "KEY=value" pairs.
param(
	[string]$Project = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path,
	[ValidateSet("headless", "fwd", "compat")][string]$Mode = "compat",
	[int]$Alive = 180,
	[int]$Wave = 10,
	[int]$Frames = 600,
	[int]$Warmup = 240,
	[int]$Hz = 0,
	[switch]$Mobile,
	[string]$Grant = "whirling_axes:4,ballista:3",
	[string]$Extra = "",
	[string]$Label = "",
	[switch]$Watch,
	[int]$Seconds = 40
)
$godot = "D:\godot\Godot_v4.7.1-stable_win64_console.exe"
$profileDir = Join-Path $env:TEMP ("hc_bench_" + [guid]::NewGuid().ToString("N").Substring(0, 8))
New-Item -ItemType Directory -Force $profileDir | Out-Null
$engine = @("--path", $Project, "--audio-driver", "Dummy", "--fixed-fps", "60")
if ($Mode -eq "headless") { $engine = @("--headless") + $engine }
else {
	$engine += "--no-focus-pause"
	if ($Mode -eq "compat") { $engine += @("--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3") }
}
$probe = @("-s", "res://src/dev/swarm_probe.gd", "--", "--probe=perf", "--alive=$Alive", "--start-wave=$Wave",
	"--frames=$Frames", "--warmup=$Warmup", "--grant=$Grant", "--meta-profile-dir=$profileDir")
if ($Watch) { $probe = @("-s", "res://src/dev/swarm_probe.gd", "--", "--probe=watch", "--seconds=$Seconds", "--start-wave=$Wave", "--meta-profile-dir=$profileDir") }
if ($Mobile) { $probe += "--mobile" }
if ($Hz -gt 0) { $probe += "--sim-hz=$Hz" }
if ($Extra -ne "") { $probe += ($Extra -split " ") }
$out = & $godot @engine @probe 2>&1 | Out-String
$perf = ($out -split "`n" | Where-Object { $_ -match "^PROBE_PERF" } | Select-Object -First 1)
$draw = ($out -split "`n" | Where-Object { $_ -match "^PROBE_DRAW" } | Select-Object -First 1)
$frameLine = ($out -split "`n" | Where-Object { $_ -match "^PROBE_FRAMES" } | Select-Object -First 1)
$watchLine = ($out -split "`n" | Where-Object { $_ -match "^PROBE_WATCH t=" } | Select-Object -Last 1)
$spikes = ($out -split "`n" | Where-Object { $_ -match "^PROBE_SPIKE" }) -join " ; "
$extraLines = ($out -split "`n" | Where-Object { $_ -match "^PROBE_(SPAWN|SPLIT)" }) -join " | "
function F($line, $key) { if ($line -match "$key=([0-9.]+)") { return $Matches[1] } else { return "?" } }
"{0} {1} mode={2} alive={3} hz={4} draw={5} rcpu={12} rgpu={13} median={6} mean={7} p95={8} max={9} phys={10} {11}" -f $Label, (Get-Date -Format "HH:mm:ss"), $Mode, (F $perf "alive_avg"), $(if ($Hz -gt 0) { $Hz } else { "def" }), (F $draw "draw_calls"), (F $perf "median_ms"), (F $perf "mean_ms"), (F $perf "p95_ms"), (F $perf "max_ms"), (F $perf "physics_ms"), $extraLines, (F $draw "render_cpu_ms"), (F $draw "render_gpu_ms")
if ($Watch) { "{0} watch wave={1} hz={2} frames: {3} | last: {4}" -f $Label, $Wave, $(if ($Hz -gt 0) { $Hz } else { "def" }), $frameLine.Trim(), $watchLine.Trim(); if ($spikes) { "   spikes: $spikes" }; Remove-Item -Recurse -Force $profileDir -ErrorAction SilentlyContinue; return }
if (-not $perf) { Write-Output $out.Substring([Math]::Max(0, $out.Length - 1500)) }
Remove-Item -Recurse -Force $profileDir -ErrorAction SilentlyContinue
