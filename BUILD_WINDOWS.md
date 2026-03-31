# Building on Windows

## Important notes
- Do NOT commit binaries. The addons/whisper_cpp/bin/ dir is ignored now — keep built DLLs locally or upload as a Release artifact.
- If you need to share a binary, upload it to a GitHub Release or cloud storage instead of committing.

Minimal BUILD_WINDOWS.md you can use (copy into the repo)

- Purpose: Build whisper_cpp_gdext for Windows (MSVC) and install runtime DLLs into the Godot project.

Prereqs
- Rust (stable) + MSVC toolchain:
  rustup toolchain install stable-x86_64-pc-windows-msvc
  rustup default stable-x86_64-pc-windows-msvc
- CMake, Visual Studio Build Tools (Desktop C++).
- LLVM (for bindgen libclang). Example via scoop:
  scoop install llvm
- Godot 4.6 (for testing)

Build (PowerShell / MSVC)
- cd git_repos/whisper-cpp-fork/godot-extension
- $env:LIBCLANG_PATH = "$env:USERPROFILE\scoop\apps\llvm\current\bin\libclang.dll"
- cargo build --release --target x86_64-pc-windows-msvc
- copy target\x86_64-pc-windows-msvc\release\whisper_cpp_gdext.dll ..\..\careless-whisper-godot\addons\whisper_cpp\bin\whisper_cpp_gdext.windows.release.x86_64.dll

Build (Git Bash)
- export LIBCLANG_PATH="/c/Users/<you>/scoop/apps/llvm/current/bin/libclang.dll"
- cd git_repos/whisper-cpp-fork/godot-extension
- GODOT_PROJECT="$(pwd)/../../careless-whisper-godot" ./build.sh --release

Verify & test
- Confirm files in git_repos/careless-whisper-godot/addons/whisper_cpp/bin/
- Place ggml model in git_repos/careless-whisper-godot/models/
- Launch Godot 4.6 and run scenes/example.tscn (watch Output/Debugger)
