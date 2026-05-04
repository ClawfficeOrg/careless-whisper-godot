# BUILD_WINDOWS.md — Windows Build Guide

This document covers building the `careless-whisper-godot` project on Windows,
including both GDExtensions (`addons/os_control` and `addons/whisper_cpp`) and the
Godot project itself.

---

## Prerequisites

### 1. Godot 4.6
- Download from https://godotengine.org/download/windows/
- Recommend adding `godot.exe` to PATH, or use the full path where needed.

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
Required by crate dependencies that use `bindgen` (e.g. `whisper-rs`).
```powershell
# Using Scoop (recommended)
scoop install llvm

# Or via winget
winget install LLVM.LLVM
```

Set `LIBCLANG_PATH` environment variable:
```powershell
# For Scoop installs:
$env:LIBCLANG_PATH = "$env:USERPROFILE\scoop\apps\llvm\current\bin"

# Or detect automatically:
$env:LIBCLANG_PATH = (Get-Command clang).Source | Split-Path
```

### 5. cmake (for whisper_cpp GDExtension)
```powershell
scoop install cmake
# or
winget install Kitware.CMake
```

---

## Building the os_control GDExtension

The `os_control` extension provides `WindowManager` and `InputInjector` classes for
cross-platform window enumeration and keyboard/mouse input injection.

```powershell
cd addons\os_control

$env:LIBCLANG_PATH = "$env:USERPROFILE\scoop\apps\llvm\current\bin"

# Debug build (faster, for dev)
cargo build --target x86_64-pc-windows-msvc

# Release build (for distribution)
cargo build --release --target x86_64-pc-windows-msvc
```

Copy the DLL to the GDExtension bin directory:
```powershell
# Debug
New-Item -ItemType Directory -Force -Path addons\os_control\bin\windows
copy addons\os_control\target\x86_64-pc-windows-msvc\debug\careless_whisper_os.dll `
     addons\os_control\bin\windows\

# Release
copy addons\os_control\target\x86_64-pc-windows-msvc\release\careless_whisper_os.dll `
     addons\os_control\bin\windows\
```

---

## Building the whisper_cpp GDExtension

The `whisper_cpp` extension provides the `WhisperCpp` class for speech transcription.
Its source lives in the sibling repo `whisper.cpp/godot-extension/`.

```powershell
# Clone the whisper.cpp fork (if not already present)
git clone https://github.com/ClawfficeOrg/whisper.cpp ..\whisper.cpp
cd ..\whisper.cpp
git checkout godot-whisper-cpp-node
cd godot-extension

$env:LIBCLANG_PATH = "$env:USERPROFILE\scoop\apps\llvm\current\bin"

cargo build --release --target x86_64-pc-windows-msvc
```

Copy the DLL to the Godot project:
```powershell
$GODOT = "C:\path\to\clawffice\careless-whisper-godot"
New-Item -ItemType Directory -Force -Path "$GODOT\addons\whisper_cpp\bin"

# Debug
copy target\x86_64-pc-windows-msvc\debug\whisper_cpp_gdext.dll `
     "$GODOT\addons\whisper_cpp\bin\whisper_cpp_gdext.windows.debug.x86_64.dll"

# Release
copy target\x86_64-pc-windows-msvc\release\whisper_cpp_gdext.dll `
     "$GODOT\addons\whisper_cpp\bin\whisper_cpp_gdext.windows.release.x86_64.dll"
```

---

## Required Runtime DLLs

### Visual C++ Redistributable
Install the latest VC++ redistributable on the target machine:
- https://aka.ms/vs/17/release/vc_redist.x64.exe

Key DLLs (normally in `C:\Windows\System32` after install):
- `VCRUNTIME140.dll`
- `MSVCP140.dll`

### Extension DLLs
Ensure these are present in `addons\<ext_name>\bin\windows\`:
- `careless_whisper_os.dll` (os_control)
- `whisper_cpp_gdext.windows.release.x86_64.dll` (whisper_cpp)

---

## MinGW Alternative (unsupported)

MinGW builds are possible but **not officially supported** for this project due to
incompatibilities between MinGW and the `windows` crate's Win32 API bindings.

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

After building both extensions:

1. Open the project in Godot 4.6
2. Go to **Project > Export**
3. Select "Windows Desktop" preset
4. Enable "Embed PCK" for single-file distribution
5. Click "Export Project"

Ensure both DLLs are included alongside the `.exe` or embedded in the PCK.

---

## Validating Required Files

Run the provided helper script to verify all required files are present:

```powershell
.\scripts\check_windows_deps.ps1
```

Or in Git Bash:
```bash
./scripts/check_windows_deps.sh
```

---

## Debugging Rust Panics

To get full Rust backtraces when the GDExtension panics, run Godot with
`RUST_BACKTRACE=1`. A helper script is included:

```powershell
.\scripts\run_godot_with_backtrace.sh --godot "C:/path/to/Godot.exe" --path .
```

This prints full Rust backtraces to the console, helpful for diagnosing panics in
the Rust extension.

---

## Non-blocking Model Loading

The `WhisperCpp` GDExtension supports non-blocking model loads: `load_model(path)`
spawns a background thread for heavy file parsing and model initialization without
calling Godot APIs from that thread. When loading completes the extension sends the
result back to the main thread and emits `model_loaded` or `transcription_error`
from the main thread.

This is the **recommended** approach for desktop UI applications. Do not call
`load_model()` from a GDScript `Thread` — that creates an unsafe cross-thread
Godot API call.

---

## Troubleshooting

| Error | Solution |
|-------|----------|
| `LIBCLANG_PATH not set` | Set `$env:LIBCLANG_PATH` to the folder containing `libclang.dll` |
| `cannot find -lvcruntime` | Install Visual Studio Build Tools with MSVC v143 |
| `DLL not found at runtime` | Copy the built `.dll` to the correct `bin\windows\` folder |
| `GetWindowRect failed` | Normal on headless/no-window sessions; not a crash |
| `InputInjector not implemented` | Stale DLL — rebuild with `cargo build --release` in `addons\os_control\` and copy the DLL to `bin\windows\` |
| `WhisperCpp` not found in ClassDB | Ensure `whisper_cpp_gdext.windows.*.dll` is in `addons\whisper_cpp\bin\` |
