/*
 * Careless Whisper OS Control
 * Rust GDExtension for cross-platform window management and OS control
 */

use godot::prelude::*;

mod window_manager;
mod input_injector;

struct CarelessWhisperOS;

#[gdextension]
unsafe impl ExtensionLibrary for CarelessWhisperOS {}
