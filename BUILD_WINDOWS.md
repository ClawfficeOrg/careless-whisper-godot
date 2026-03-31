# BUILD_WINDOWS.md — Windows Build Guide

This document covers building the `careless-whisper-godot` project on Windows,
including the Rust GDExtension (`addons/os_control`) and the Godot project itself.

---

## Prerequisites

### 1. Godot 4.3+
- Download from https://godotengine.org/download/windows/
- Add `godot.exe` to PATH (or use the full path in build scripts)

### 2. Rust + MSVC Toolchain
```powershell
# Install rustup from https://rustup.rs
rustup toolchain install stable-x86_64-pc-windows-msvc
rustup default stable-x86_64-pc-windows-msvc
```

### 3. Visual Studio Build Tools (MSVC)
Required for linking. Install either:
- **Visual Studio 2022** with "Desktop development with C++" workload, **or**
- **Visual Studio Build Tools 2022** (standalone, smaller)
  - https://aka.ms/vs/17/release/vs_BuildTools.exe
  - Select: "MSVC v143 - VS 2022 C++ x64/x86 build tools" + "Windows 11 SDK"

### 4. LLVM / libclang (for bindgen)
Required by some crate dependencies that use `bindgen`.
```powershell
# Using Scoop (recommended)
scoop install llvm

# Or via winget
winget install LLVM.LLVM
```

Set `LIBCLANG_PATH` environment variable:
```powershell
$env:LIBCLANG_PATH = (Get-Command clang).Source | Split-Path
# Or for Scoop installs:
$env:LIBCLANG_PATH = "$env:USERPROFILE\scoop\apps\llvm\current\bin"
```

---

## Building the Rust GDExtension

```powershell
cd addons\os_control

# Set libclang path if needed
$env:LIBCLANG_PATH = "$env:USERPROFILE\scoop\apps\llvm\current\bin"

# Debug build (faster, for dev)
cargo build --target x86_64-pc-windows-msvc

# Release build (for distribution)
cargo build --release --target x86_64-pc-windows-msvc
```

Output DLL location:
- Debug:   `addons\os_control\target\x86_64-pc-windows-msvc\debug\careless_whisper_os.dll`
- Release: `addons\os_control\target\x86_64-pc-windows-msvc\release\careless_whisper_os.dll`

Copy the DLL to the GDExtension bin directory:
```powershell
# Debug
copy addons\os_control\target\x86_64-pc-windows-msvc\debug\careless_whisper_os.dll `
     addons\os_control\bin\windows\

# Release
copy addons\os_control\target\x86_64-pc-windows-msvc\release\careless_whisper_os.dll `
     addons\os_control\bin\windows\
```

---

## Required Runtime DLLs

When distributing or running the built extension, the following DLLs must be present:

### Visual C++ Redistributable
The Rust MSVC toolchain links against the Visual C++ runtime.
Install the latest VC++ redistributable on the target machine:
- https://aka.ms/vs/17/release/vc_redist.x64.exe

Key DLLs (usually in `C:\Windows\System32` after install):
- `VCRUNTIME140.dll`
- `MSVCP140.dll`

### Godot GDExtension Runtime
Place these in the project directory or next to the executable:
- `careless_whisper_os.dll` (your built extension)

---

## MinGW Alternative (if MSVC not available)

MinGW builds are possible but **not officially supported** for this project due to
incompatibilities between MinGW and the `windows` crate's Win32 API bindings.

If you need MinGW:
```powershell
rustup toolchain install stable-x86_64-pc-windows-gnu
rustup target add x86_64-pc-windows-gnu
cargo build --target x86_64-pc-windows-gnu
```

Known issues with MinGW:
- Some Win32 types may not link correctly
- The `windows` crate prefers MSVC
- May require additional `windres` / `rc` tooling

---

## Godot Project Export

After building the extension:

1. Open the project in Godot
2. Go to **Project > Export**
3. Select "Windows Desktop" preset
4. Enable "Embed PCK" for single-file distribution
5. Click "Export Project"

Ensure `careless_whisper_os.dll` is included in the export (add to PCK or place
alongside the `.exe`).

---

## Validating Required Files

Run `scripts/check_windows_deps.ps1` (or `scripts/check_windows_deps.sh` in Git Bash)
to validate that required files are present before running or distributing.

```powershell
.\scripts\check_windows_deps.ps1
```

---

## Troubleshooting

| Error | Solution |
|-------|----------|
| `LIBCLANG_PATH not set` | Set `$env:LIBCLANG_PATH` to the folder containing `libclang.dll` |
| `cannot find -lvcruntime` | Install Visual Studio Build Tools with MSVC v143 |
| `DLL not found at runtime` | Copy the built `.dll` to `addons\os_control\bin\windows\` |
| `GetWindowRect failed` | Normal on headless/no-window sessions; not a crash |
| `InputInjector not implemented` | SendInput wrappers are stubs — see `addons\os_control\src\input_injector.rs` |
