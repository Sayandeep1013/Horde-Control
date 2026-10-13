# Runs the phone layout audit (src/dev/layout_audit.gd, D370) over the size x inset matrix.
#   powershell -File tools/dev/run_layout_audit.ps1 [-Screens a,b] [-Sizes "2400x1080;1280x720"] [-Insets "0,0,0,0;110,0,0,40"] [-Parallel 3]
# Writes sandbox/audit/<size>_<inset>_<touch|desk>.json and prints one totals line per run.
# Sizes and insets are ';'-separated (the insets contain commas). Each run is a fresh Godot process with a fresh
# meta profile (first-visit hints and explainers must show), so runs can go in parallel.
param(
	[string]$Sizes = "2400x1080;2340x1080;3200x1440;1600x720;1280x720;1920x1200;2048x1536",
	[string]$Insets = "0,0,0,0;110,0,0,40;0,0,110,40",
	[string]$Screens = "",
	[string]$Godot = "D:\godot\Godot_v4.7.1-stable_win64_console.exe",
	[string]$Profile = "$env:TEMP\hc_audit_profile",
	[switch]$NoDesktop,
	[int]$Parallel = 3,
	[int]$TimeoutSec = 900
)
$root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Set-Location $root
New-Item -ItemType Directory -Force -Path $Profile | Out-Null
New-Item -ItemType Directory -Force -Path "sandbox/audit" | Out-Null

$jobs = @()
foreach ($s in ($Sizes -split ";" | Where-Object { $_ -ne "" })) {
	foreach ($i in ($Insets -split ";" | Where-Object { $_ -ne "" })) { $jobs += ,@($s, $i, $true) }
}
if (-not $NoDesktop) { $jobs += ,@("1920x1080", "0,0,0,0", $false) }

function Start-Audit($job) {
	$size = $job[0]; $inset = $job[1]; $touch = $job[2]
	$tag = "{0}_{1}_{2}" -f $size, ($inset -replace ",", "-"), ($(if ($touch) { "touch" } else { "desk" }))
	$prof = Join-Path $Profile ("{0}_{1}" -f $tag, (Get-Date -Format "HHmmss"))
	New-Item -ItemType Directory -Force -Path $prof | Out-Null
	$argv = @("--path", ".", "--audio-driver", "Dummy", "res://src/dev/layout_audit.tscn", "--", "--size=$size", "--no-focus-pause", "--out=sandbox/audit/$tag.json", "--meta-profile-dir=$prof")
	if ($touch) { $argv += "--touch-ui" } else { $argv += "--no-touch-ui" }
	if ($inset -ne "0,0,0,0") { $argv += "--safe-inset=$inset" }
	if ($Screens -ne "") { $argv += "--screens=$Screens" }
	$p = Start-Process -FilePath $Godot -ArgumentList $argv -PassThru -NoNewWindow -RedirectStandardOutput "sandbox/audit/$tag.log" -RedirectStandardError "sandbox/audit/$tag.err.log"
	return @{ Proc = $p; Tag = $tag; Started = Get-Date }
}

$running = @()
$queue = [System.Collections.ArrayList]@($jobs)
while ($queue.Count -gt 0 -or $running.Count -gt 0) {
	while ($queue.Count -gt 0 -and $running.Count -lt $Parallel) {
		$running += Start-Audit $queue[0]
		$queue.RemoveAt(0)
	}
	Start-Sleep -Seconds 2
	$still = @()
	foreach ($r in $running) {
		if ($r.Proc.HasExited) {
			$line = Select-String -Path "sandbox/audit/$($r.Tag).log" -Pattern "AUDIT_TOTAL" | Select-Object -Last 1
			Write-Output ("{0,-34} {1}" -f $r.Tag, $line.Line)
		} elseif (((Get-Date) - $r.Started).TotalSeconds -gt $TimeoutSec) {
			Stop-Process -Id $r.Proc.Id -Force
			Write-Output "TIMEOUT $($r.Tag)"
		} else { $still += $r }
	}
	$running = $still
}
