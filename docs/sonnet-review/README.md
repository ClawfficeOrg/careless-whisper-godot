Sonnet-style review: careless-whisper (feature/windows-build)

This folder contains a short review, docs references, and build instructions gathered during a source review and compile-check.

Summary:
- Updated os_control crate to fix Windows API usage (RECT import, HWND null checks) and Godot binding types (VarDictionary/Variant usage in arrays).
- Fixed Cargo.toml to use xcb 1.7 + xcb-wm for EWMH support on Linux and kept Windows/macOS targets intact.
- Added .gitattributes and .gitignore updates to normalize line endings and ignore build artifacts.

Remaining manual steps:
- Windows MSVC build must be run on Windows (cargo build --release --target x86_64-pc-windows-msvc). Ensure Visual Studio Build Tools and LLVM (for bindgen) are installed. Set LIBCLANG_PATH to libclang.dll.
- Test runtime DLL loading in Godot; install Visual C++ redistributable if DLL load errors occur.

Commands (Windows - PowerShell):
$env:LIBCLANG_PATH = "$env:USERPROFILE\\scoop\\apps\\llvm\\current\\bin\\libclang.dll"
cd addons/os_control
rustup toolchain install stable-x86_64-pc-windows-msvc
rustup default stable-x86_64-pc-windows-msvc
cargo build --release --target x86_64-pc-windows-msvc

Commands (Linux / Git Bash):
export LIBCLANG_PATH="/c/Users/<you>/scoop/apps/llvm/current/bin/libclang.dll"
cd git_repos/whisper-cpp-fork/godot-extension
GODOT_PROJECT="$(pwd)/../../careless-whisper-godot" ./build.sh --release

References (docs.rs / crates.io):
- godot-core / godot 0.4.x docs: https://docs.rs/godot-core
- windows crate features: https://crates.io/crates/windows
- xcb crate: https://docs.rs/xcb
- xcb-wm crate: https://crates.io/crates/xcb-wm
- bindgen/libclang: https://docs.rs/bindgen

