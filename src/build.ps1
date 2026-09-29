# Concatenate the Lonestar parts into one client script.
# Order matters: 1b defines the local MachoMenu* implementation that the
# widget parts call, so it has to load before part 2 builds the window.

$ErrorActionPreference = "Stop"

$root     = "C:\Users\mhonr\Downloads\Lowbat\lua"
$build    = Join-Path $root "_build"
$nui      = Join-Path $root "_nui"
$out      = Join-Path $root "Lonestar.lua"
$stage    = "C:\Users\mhonr\Downloads\143.14.88.237\resources\lonestar"

$order = @(
    "p1_core.lua",
    "p1b_ui.lua",
    "p2_data.lua",
    "p3_self.lua",
    "p4_toggles.lua",
    "p5_move.lua",
    "p6_teleport_troll.lua",
    "p7_weapons.lua",
    "p8_vehicle.lua",
    "p9_server_exploit.lua",
    "p10_nuke_settings.lua"
)

$chunks = New-Object System.Collections.Generic.List[string]
foreach ($name in $order) {
    $path = Join-Path $build $name
    if (-not (Test-Path -LiteralPath $path)) { throw "missing part: $name" }
    $chunks.Add(("-" * 74))
    $chunks.Add("-- >>> $name")
    $chunks.Add(("-" * 74))
    $chunks.Add("")
    $chunks.Add((Get-Content -LiteralPath $path -Raw))
    $chunks.Add("")
}

$merged = $chunks -join "`r`n"
[System.IO.File]::WriteAllText($out, $merged, (New-Object System.Text.UTF8Encoding($false)))

$lines = (Get-Content -LiteralPath $out).Count
"built  $out  ({0} lines, {1} bytes)" -f $lines, (Get-Item -LiteralPath $out).Length

# Copy the browser page next to the client script so it can be published
# to GitHub Pages (the menu loads it over https from CONFIG.ui.url).
$stageNui = Join-Path $stage "_nui"
if (Test-Path -LiteralPath $stage) {
    New-Item -ItemType Directory -Path $stageNui -Force | Out-Null
    Copy-Item -Path (Join-Path $nui "*") -Destination $stageNui -Force
    Copy-Item -LiteralPath $out -Destination (Join-Path $stage "client_script.lua") -Force
    "staged client_script.lua + _nui\ to $stage"
}
