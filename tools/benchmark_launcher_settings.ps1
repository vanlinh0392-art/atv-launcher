param(
  [string]$Device = '192.168.1.111:5555',
  [string]$Adb = 'adb',
  [string]$Package = 'com.atv.launcher',
  [string]$Component = 'com.atv.launcher/.MainActivity',
  [string]$OutputRoot = 'build/benchmarks/launcher_settings'
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

function Invoke-AdbText {
  param(
    [string[]]$Arguments,
    [switch]$IgnoreExitCode
  )

  $output = & $Adb @Arguments 2>&1 | Out-String
  if (-not $IgnoreExitCode -and $LASTEXITCODE -ne 0) {
    throw "adb failed: $($Arguments -join ' ')`n$output"
  }
  return $output
}

function Invoke-BenchmarkIntent {
  param(
    [string]$ActionName,
    [string]$SessionId,
    [string]$Route = '',
    [bool]$AutoFocusDetail = $true,
    [bool]$BypassSettingsSecurity = $true
  )

  $autoFocusValue = if ($AutoFocusDetail) { 'true' } else { 'false' }
  $bypassValue = if ($BypassSettingsSecurity) { 'true' } else { 'false' }
  $args = @(
    '-s', $Device,
    'shell', 'am', 'start', '-W',
    '-n', $Component,
    '-a', 'com.atv.launcher.DEBUG_BENCHMARK',
    '--es', 'action', $ActionName,
    '--es', 'sessionId', $SessionId,
    '--es', 'route', $Route,
    '--ez', 'autoFocusDetail', $autoFocusValue,
    '--ez', 'bypassSettingsSecurity', $bypassValue
  )
  Invoke-AdbText -Arguments $args | Out-Null
}

function Wait-LogPattern {
  param(
    [string]$Pattern,
    [int]$TimeoutSeconds = 15
  )

  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  while ((Get-Date) -lt $deadline) {
    $dump = Invoke-AdbText -Arguments @('-s', $Device, 'logcat', '-d') -IgnoreExitCode
    if ($dump -match $Pattern) {
      return $dump
    }
    Start-Sleep -Milliseconds 250
  }

  throw "Timed out waiting for log pattern: $Pattern"
}

function Send-KeySequence {
  param(
    [string[]]$Keys,
    [int]$DelayMilliseconds = 120
  )

  foreach ($key in $Keys) {
    $code = switch ($key.ToUpperInvariant()) {
      'UP' { 'KEYCODE_DPAD_UP' }
      'DOWN' { 'KEYCODE_DPAD_DOWN' }
      'LEFT' { 'KEYCODE_DPAD_LEFT' }
      'RIGHT' { 'KEYCODE_DPAD_RIGHT' }
      'OK' { 'KEYCODE_DPAD_CENTER' }
      default { throw "Unsupported key: $key" }
    }
    Invoke-AdbText -Arguments @('-s', $Device, 'shell', 'input', 'keyevent', $code) | Out-Null
    Start-Sleep -Milliseconds $DelayMilliseconds
  }
}

function Get-PssKb {
  param([string]$Meminfo)

  $match = [regex]::Match($Meminfo, '(?m)^\s*TOTAL(?:\s+PSS:)?\s+(\d+)')
  if ($match.Success) {
    return [int]$match.Groups[1].Value
  }
  return $null
}

function New-KeySequence {
  param(
    [int]$DownCount,
    [int]$UpCount,
    [string[]]$Horizontal = @()
  )

  $keys = New-Object System.Collections.Generic.List[string]
  for ($index = 0; $index -lt $DownCount; $index += 1) {
    $keys.Add('DOWN')
  }
  for ($index = 0; $index -lt $UpCount; $index += 1) {
    $keys.Add('UP')
  }
  foreach ($key in $Horizontal) {
    $keys.Add($key)
  }
  return $keys.ToArray()
}

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$outputDir = Join-Path $repoRoot $OutputRoot
$runDir = Join-Path $outputDir $timestamp
New-Item -ItemType Directory -Path $runDir -Force | Out-Null

$scenarios = @(
  @{
    Name = 'open_home_layout'
    Route = 'home_layout_panel'
    Keys = @()
    WaitForDpad = $false
  },
  @{
    Name = 'dpad_home_layout'
    Route = 'home_layout_panel'
    Keys = New-KeySequence -DownCount 12 -UpCount 12 -Horizontal @('RIGHT', 'RIGHT', 'LEFT', 'LEFT', 'RIGHT', 'LEFT')
    WaitForDpad = $true
  },
  @{
    Name = 'dpad_wallpaper_media'
    Route = 'wallpaper_panel'
    Keys = New-KeySequence -DownCount 10 -UpCount 10 -Horizontal @('RIGHT', 'RIGHT', 'LEFT', 'LEFT', 'RIGHT', 'LEFT')
    WaitForDpad = $true
  },
  @{
    Name = 'dpad_profiles_security'
    Route = 'profiles_security_panel'
    Keys = New-KeySequence -DownCount 8 -UpCount 8
    WaitForDpad = $true
  }
)

Write-Host "Saving benchmark artifacts to $runDir"
Invoke-AdbText -Arguments @('-s', $Device, 'wait-for-device') | Out-Null

$summaryRows = New-Object System.Collections.Generic.List[object]

foreach ($scenario in $scenarios) {
  $name = $scenario.Name
  $route = $scenario.Route
  $waitForDpad = [bool]$scenario.WaitForDpad
  $keys = [string[]]$scenario.Keys
  $sessionId = "$timestamp-$name"
  $scenarioDir = Join-Path $runDir $name
  New-Item -ItemType Directory -Path $scenarioDir -Force | Out-Null

  Write-Host "Running $name ($route)"
  Invoke-AdbText -Arguments @('-s', $Device, 'logcat', '-c') -IgnoreExitCode | Out-Null

  $baselineMem = Invoke-AdbText -Arguments @('-s', $Device, 'shell', 'dumpsys', 'meminfo', $Package) -IgnoreExitCode
  Set-Content -Path (Join-Path $scenarioDir 'meminfo_before.txt') -Value $baselineMem -Encoding UTF8

  Invoke-BenchmarkIntent -ActionName 'open_launcher_settings' -SessionId $sessionId -Route $route

  $readyPattern = "FLauncherPerf settings_benchmark_ready .*sessionId=$([regex]::Escape($sessionId))"
  Wait-LogPattern -Pattern $readyPattern | Out-Null

  if ($waitForDpad) {
    Send-KeySequence -Keys $keys
    $dpadSummaryPattern = "FLauncherPerf settings_benchmark_summary .*sessionId=$([regex]::Escape($sessionId)).*phase=dpad"
    Wait-LogPattern -Pattern $dpadSummaryPattern | Out-Null
  } else {
    $openSummaryPattern = "FLauncherPerf settings_benchmark_summary .*sessionId=$([regex]::Escape($sessionId)).*phase=open"
    Wait-LogPattern -Pattern $openSummaryPattern | Out-Null
  }

  Start-Sleep -Milliseconds 250

  $logDump = Invoke-AdbText -Arguments @('-s', $Device, 'logcat', '-d') -IgnoreExitCode
  Set-Content -Path (Join-Path $scenarioDir 'logcat.txt') -Value $logDump -Encoding UTF8

  $finalMem = Invoke-AdbText -Arguments @('-s', $Device, 'shell', 'dumpsys', 'meminfo', $Package) -IgnoreExitCode
  Set-Content -Path (Join-Path $scenarioDir 'meminfo_after.txt') -Value $finalMem -Encoding UTF8

  $gfxinfo = Invoke-AdbText -Arguments @('-s', $Device, 'shell', 'dumpsys', 'gfxinfo', $Package, 'framestats') -IgnoreExitCode
  Set-Content -Path (Join-Path $scenarioDir 'gfxinfo_framestats.txt') -Value $gfxinfo -Encoding UTF8

  $perfLines = ($logDump -split "`r?`n") | Where-Object {
    $_ -match "FLauncherPerf .*sessionId=$([regex]::Escape($sessionId))"
  }
  Set-Content -Path (Join-Path $scenarioDir 'perf_summary.txt') -Value ($perfLines -join [Environment]::NewLine) -Encoding UTF8

  $beforePss = Get-PssKb -Meminfo $baselineMem
  $afterPss = Get-PssKb -Meminfo $finalMem
  $summaryRows.Add([pscustomobject]@{
    scenario = $name
    route = $route
    pssBeforeKb = $beforePss
    pssAfterKb = $afterPss
  }) | Out-Null

  Write-Host "  PSS: $beforePss KB -> $afterPss KB"
  foreach ($line in $perfLines) {
    Write-Host "  $line"
  }

  Invoke-BenchmarkIntent -ActionName 'close_launcher_settings' -SessionId $sessionId -Route $route
  Start-Sleep -Milliseconds 500
}

$summaryRows |
  ConvertTo-Json -Depth 3 |
  Set-Content -Path (Join-Path $runDir 'summary.json') -Encoding UTF8

Write-Host ''
Write-Host 'Benchmark complete. Summary:'
$summaryRows | Format-Table -AutoSize
