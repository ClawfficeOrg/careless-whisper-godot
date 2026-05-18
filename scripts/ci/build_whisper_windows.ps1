<#
.SYNOPSIS
    Build the whisper_cpp GDExtension DLL and copy it into the Godot project tree.

.DESCRIPTION
    Invoked by .github/workflows/ci-windows.yml.  Can also be run locally to
    reproduce the CI build on a Windows machine without invoking the full workflow.

    Requirements
    ------------
    - Rust + MSVC toolchain installed (rustup, cargo)
    - LIBCLANG_PATH environment variable pointing to the LLVM bin directory
    - Visual Studio Build Tools 2022 (MSVC v143, Windows SDK)
    - cmake on PATH (required by whisper.cpp's C build)

    Usage (local)
    -------------
    $env:LIBCLANG_PATH = "C:\Program Files\LLVM\bin"
    .\scripts\ci\build_whisper_windows.ps1 `
        -WhisperDir   "..\whisper.cpp\godot-extension" `
        -GodotProject "." `
        -Arch         "x86_64" `
        -RustTarget   "x86_64-pc-windows-msvc"

.PARAMETER WhisperDir
    Absolute or relative path to the godot-extension directory inside whisper.cpp.
    Defaults to "..\whisper.cpp\godot-extension" relative to this script's location.

.PARAMETER GodotProject
    Absolute or relative path to the root of careless-whisper-godot.
    Defaults to the directory two levels above this script (repo root).

.PARAMETER Arch
    Architecture tag used in the output DLL filename, e.g. "x86_64".
    Defaults to "x86_64".

.PARAMETER RustTarget
    Full Rust target triple, e.g. "x86_64-pc-windows-msvc".
    Defaults to "x86_64-pc-windows-msvc".
#>

[CmdletBinding()]
param(
    [string] $WhisperDir   = "",
    [string] $GodotProject = "",
    [string] $Arch         = "x86_64",
    [string] $RustTarget   = "x86_64-pc-windows-msvc"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ── Resolve paths ────────────────────────────────────────────────────────────

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

if ([string]::IsNullOrEmpty($WhisperDir)) {
    $WhisperDir = Join-Path $ScriptDir "..\..\whisper.cpp\godot-extension"
}
if ([string]::IsNullOrEmpty($GodotProject)) {
    $GodotProject = Join-Path $ScriptDir "..\..\"
}

$WhisperDir   = (Resolve-Path $WhisperDir).Path
$GodotProject = (Resolve-Path $GodotProject).Path

Write-Host "==> whisper-dir  : $WhisperDir"
Write-Host "==> godot-project: $GodotProject"
Write-Host "==> arch         : $Arch"
Write-Host "==> rust-target  : $RustTarget"

# ── Validate LIBCLANG_PATH ───────────────────────────────────────────────────

if ([string]::IsNullOrEmpty($env:LIBCLANG_PATH)) {
    Write-Error "LIBCLANG_PATH is not set.  Install LLVM and set the variable to its bin/ directory."
}
if (-not (Test-Path $env:LIBCLANG_PATH)) {
    Write-Error "LIBCLANG_PATH directory does not exist: $env:LIBCLANG_PATH"
}
Write-Host "==> LIBCLANG_PATH: $env:LIBCLANG_PATH"

# ── Ensure the Rust target is installed ──────────────────────────────────────

Write-Host "==> Ensuring Rust target $RustTarget is installed …"
& rustup target add $RustTarget
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# ── Build ─────────────────────────────────────────────────────────────────────

Write-Host "==> Running cargo build --release --target $RustTarget …"
Push-Location $WhisperDir
try {
    & cargo build --release --target $RustTarget
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
} finally {
    Pop-Location
}

# ── Locate the built DLL ──────────────────────────────────────────────────────

$BuiltDll = Join-Path $WhisperDir "target\$RustTarget\release\whisper_cpp_gdext.dll"
if (-not (Test-Path $BuiltDll)) {
    Write-Error "cargo build succeeded but expected DLL not found: $BuiltDll"
}

# ── Copy to Godot addon bin directory ─────────────────────────────────────────
# Expected name matches the path declared in addons/whisper_cpp/whisper_cpp.gdextension:
#   windows.release.x86_64 = "res://addons/whisper_cpp/bin/whisper_cpp_gdext.windows.release.x86_64.dll"

$DestDir = Join-Path $GodotProject "addons\whisper_cpp\bin"
$DestDll = Join-Path $DestDir "whisper_cpp_gdext.windows.release.$Arch.dll"

Write-Host "==> Creating destination directory: $DestDir"
New-Item -ItemType Directory -Force -Path $DestDir | Out-Null

Write-Host "==> Copying DLL: $BuiltDll -> $DestDll"
Copy-Item -Force $BuiltDll $DestDll

$size = (Get-Item $DestDll).Length
Write-Host "==> Done.  DLL size: $size bytes"
