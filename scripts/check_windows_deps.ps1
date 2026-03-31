# check_windows_deps.ps1
# Validate required files for careless-whisper-godot Windows build.
# Run from PowerShell in the repository root.
#
# Usage: .\scripts\check_windows_deps.ps1 [-Release]

param(
    [switch]$Release
)

$BuildType = if ($Release) { "release" } else { "debug" }
$Target = "x86_64-pc-windows-msvc"
$RepoRoot = Split-Path -Parent $PSScriptRoot

$DllSrc  = "$RepoRoot\addons\os_control\target\$Target\$BuildType\careless_whisper_os.dll"
$DllDest = "$RepoRoot\addons\os_control\bin\windows\careless_whisper_os.dll"

$Pass = 0
$Fail = 0

function Check-File($Label, $Path) {
    if (Test-Path $Path) {
        Write-Host "  [OK]   $Label" -ForegroundColor Green
        $script:Pass++
    } else {
        Write-Host "  [MISS] $Label" -ForegroundColor Red
        Write-Host "         Expected at: $Path"
        $script:Fail++
    }
}

Write-Host "=== careless-whisper Windows dependency check ==="
Write-Host "Build type: $BuildType"
Write-Host ""

Write-Host "--- Rust toolchain ---"
$cargoVer = cargo --version 2>$null
if ($cargoVer) {
    Write-Host "  [OK]   cargo: $cargoVer" -ForegroundColor Green
    $Pass++
} else {
    Write-Host "  [MISS] cargo not found — install rustup from https://rustup.rs" -ForegroundColor Red
    $Fail++
}

$installedTargets = rustup target list --installed 2>$null
if ($installedTargets -match [regex]::Escape($Target)) {
    Write-Host "  [OK]   rustup target: $Target" -ForegroundColor Green
    $Pass++
} else {
    Write-Host "  [MISS] rustup target $Target not installed" -ForegroundColor Red
    Write-Host "         Run: rustup target add $Target"
    $Fail++
}

Write-Host ""
Write-Host "--- Built artifacts ---"
Check-File "Extension DLL (build output)" $DllSrc
Check-File "Extension DLL (bin/ deploy)"  $DllDest

Write-Host ""
Write-Host "--- Visual C++ Redistributable ---"
$VcFiles = @("VCRUNTIME140.dll", "MSVCP140.dll")
foreach ($dll in $VcFiles) {
    $sysPath = Join-Path "$env:SystemRoot\System32" $dll
    Check-File $dll $sysPath
}

Write-Host ""
Write-Host "--- LLVM/libclang (for bindgen) ---"
if ($env:LIBCLANG_PATH) {
    Check-File "libclang.dll" (Join-Path $env:LIBCLANG_PATH "libclang.dll")
} else {
    Write-Host "  [WARN] LIBCLANG_PATH not set — needed only if rebuilding crates with bindgen" -ForegroundColor Yellow
    Write-Host "         Install LLVM and set: `$env:LIBCLANG_PATH = 'C:\path\to\llvm\bin'"
}

Write-Host ""
Write-Host "--- Summary ---"
Write-Host "  Passed:  $Pass"
Write-Host "  Missing: $Fail"
Write-Host ""

if ($Fail -gt 0) {
    Write-Host "Some checks failed. See BUILD_WINDOWS.md for setup instructions." -ForegroundColor Red
    exit 1
} else {
    Write-Host "All required files present. Ready to run on Windows." -ForegroundColor Green
}
