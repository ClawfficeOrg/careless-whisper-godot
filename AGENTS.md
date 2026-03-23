# AGENTS.md - AI Agent Guidelines

This file provides guidance for AI agents (Claude, GPT, etc.) working on this codebase.

## Project Overview

Careless Whisper is a Godot 4.6 project that provides speech recognition using whisper.cpp via a GDExtension.

## Before Committing

**Always run the linter before committing GDScript changes:**

```bash
./scripts/lint.sh
```

For CI/CD or pre-commit hooks, use `--strict` to fail on errors:

```bash
./scripts/lint.sh --strict
```

## GDScript Type Inference

When using `:=` type inference, be careful with:

1. **Dictionary access** - Returns `Variant`, needs explicit type:
   ```gdscript
   # Bad: infers as Variant
   var value := my_dict["key"]

   # Good: explicit type
   var value: String = my_dict["key"]
   ```

2. **Array access** - Returns `Variant` for untyped arrays:
   ```gdscript
   # Bad: infers as Variant
   var item := my_array[0]

   # Good: explicit type or typed array
   var item: String = my_array[0]
   # or
   var items: Array[String] = ["a", "b"]
   var item := items[0]  # OK: infers as String
   ```

3. **Method calls on untyped variables** - Return type may be `Variant`:
   ```gdscript
   # If _whisper is untyped Node
   var result := _whisper.load_model(path)  # Bad

   # Better: explicit type
   var result: bool = _whisper.load_model(path)
   ```

## Code Style

- Use explicit types for public function signatures
- Use `:=` only when the type is unambiguous (literals, typed method returns)
- Keep lines under 100 characters
- Use snake_case for functions and variables
- Use PascalCase for classes and signals

## Project Structure

```
scripts/
├── autoload/       # Global singletons (SignalBus, ConfigManager, ModelManager)
├── ui/             # UI components (main, config_dialog, model_browser, etc.)
└── lint.sh         # GDScript validation script
scenes/
└── main.tscn       # Main application scene
addons/
└── whisper_cpp/    # GDExtension for whisper.cpp
```

## Running the Project

```bash
./run.sh
```

Or in Godot editor: open project and press F5.
