use godot::prelude::*;

/// InputInjector - Cross-platform keyboard and mouse input simulation
///
/// Provides keyboard and mouse input injection for voice commands.
/// Used for vim-like modal voice control.
#[derive(GodotClass)]
#[class(init, base=RefCounted)]
pub struct InputInjector {
    base: Base<RefCounted>,
}

#[godot_api]
impl InputInjector {
    /// Type text string
    ///
    /// Simulates typing a text string character by character
    #[func]
    pub fn type_text(&self, text: String) -> bool {
        #[cfg(target_os = "windows")]
        {
            self.type_text_windows(&text)
        }

        #[cfg(target_os = "macos")]
        {
            self.type_text_macos(&text)
        }

        #[cfg(target_os = "linux")]
        {
            self.type_text_linux(&text)
        }

        #[cfg(not(any(target_os = "windows", target_os = "macos", target_os = "linux")))]
        {
            godot_error!("Unsupported platform for input injection");
            false
        }
    }

    /// Press key combination
    ///
    /// Simulates pressing a key combination (e.g., "ctrl+c", "alt+tab")
    /// Keys are separated by "+" signs
    #[func]
    pub fn press_key(&self, key_combo: String) -> bool {
        let keys: Vec<&str> = key_combo.split('+').collect();

        #[cfg(target_os = "windows")]
        {
            self.press_key_windows(&keys)
        }

        #[cfg(target_os = "macos")]
        {
            self.press_key_macos(&keys)
        }

        #[cfg(target_os = "linux")]
        {
            self.press_key_linux(&keys)
        }

        #[cfg(not(any(target_os = "windows", target_os = "macos", target_os = "linux")))]
        {
            godot_error!("Unsupported platform for input injection");
            false
        }
    }

    /// Move mouse to position
    #[func]
    pub fn move_mouse(&self, x: i32, y: i32) -> bool {
        #[cfg(target_os = "windows")]
        {
            self.move_mouse_windows(x, y)
        }

        #[cfg(target_os = "macos")]
        {
            self.move_mouse_macos(x, y)
        }

        #[cfg(target_os = "linux")]
        {
            self.move_mouse_linux(x, y)
        }

        #[cfg(not(any(target_os = "windows", target_os = "macos", target_os = "linux")))]
        {
            godot_error!("Unsupported platform for input injection");
            false
        }
    }

    /// Click mouse button
    ///
    /// button: "left", "right", "middle"
    #[func]
    pub fn click_mouse(&self, button: String) -> bool {
        #[cfg(target_os = "windows")]
        {
            self.click_mouse_windows(&button)
        }

        #[cfg(target_os = "macos")]
        {
            self.click_mouse_macos(&button)
        }

        #[cfg(target_os = "linux")]
        {
            self.click_mouse_linux(&button)
        }

        #[cfg(not(any(target_os = "windows", target_os = "macos", target_os = "linux")))]
        {
            godot_error!("Unsupported platform for input injection");
            false
        }
    }
}

// Windows implementation
//
// NOTE: SendInput / CGEvent wrappers are not yet implemented.
// Functions log a clear error via godot_error! and return false so callers
// can surface the failure rather than silently succeeding.
#[cfg(target_os = "windows")]
impl InputInjector {
    fn type_text_windows(&self, text: &str) -> bool {
        use windows::Win32::UI::Input::KeyboardAndMouse::{INPUT, INPUT_0, KEYBDINPUT, SendInput, KEYEVENTF_UNICODE, KEYEVENTF_KEYUP};

        if text.is_empty() {
            return false;
        }

        let mut inputs: Vec<INPUT> = Vec::with_capacity(text.encode_utf16().count() * 2);
        for ch in text.encode_utf16() {
            let ki = KEYBDINPUT { wVk: 0, wScan: ch, dwFlags: KEYEVENTF_UNICODE.0 as u32, time: 0, dwExtraInfo: 0 };
            let input = INPUT { Anonymous: INPUT_0 { ki } };
            inputs.push(input);
            let ki_up = KEYBDINPUT { wVk: 0, wScan: ch, dwFlags: (KEYEVENTF_UNICODE.0 | KEYEVENTF_KEYUP.0) as u32, time: 0, dwExtraInfo: 0 };
            let input_up = INPUT { Anonymous: INPUT_0 { ki: ki_up } };
            inputs.push(input_up);
        }

        unsafe {
            let sent = SendInput(&inputs, std::mem::size_of::<INPUT>() as i32);
            if sent == 0 {
                godot_error!("[InputInjector] SendInput failed to send text '{}'", text);
                return false;
            }
        }

        true
}

    fn press_key_windows(&self, keys: &[&str]) -> bool {
        use windows::Win32::UI::Input::KeyboardAndMouse::{INPUT, INPUT_0, KEYBDINPUT, SendInput, KEYEVENTF_KEYUP};

        if keys.is_empty() {
            return false;
        }

        fn map_key(s: &str) -> Option<u16> {
            match s.to_lowercase().as_str() {
                "ctrl" | "control" => Some(0x11),
                "enter" | "return" => Some(0x0D),
                "escape" | "esc" => Some(0x1B),
                "tab" => Some(0x09),
                "space" => Some(0x20),
                k if k.len() == 1 => Some(k.chars().next().unwrap() as u16),
                _ => None,
            }
        }

        let mut inputs: Vec<INPUT> = Vec::new();
        for &k in keys.iter() {
            if let Some(vk) = map_key(k) {
                let ki = KEYBDINPUT { wVk: vk as u16, wScan: 0, dwFlags: 0, time: 0, dwExtraInfo: 0 };
                inputs.push(INPUT { Anonymous: INPUT_0 { ki } });
            }
        }
        for &k in keys.iter().rev() {
            if let Some(vk) = map_key(k) {
                let ki = KEYBDINPUT { wVk: vk as u16, wScan: 0, dwFlags: KEYEVENTF_KEYUP.0 as u32, time: 0, dwExtraInfo: 0 };
                inputs.push(INPUT { Anonymous: INPUT_0 { ki } });
            }
        }

        unsafe {
            let sent = SendInput(&inputs, std::mem::size_of::<INPUT>() as i32);
            if sent == 0 {
                godot_error!("[InputInjector] SendInput failed for keys: {:?}", keys);
                return false;
            }
        }

        true
}

    fn move_mouse_windows(&self, x: i32, y: i32) -> bool {
        use windows::Win32::UI::WindowsAndMessaging::SetCursorPos;
        unsafe {
            let ok = SetCursorPos(x, y).as_bool();
            if !ok {
                godot_error!("[InputInjector] SetCursorPos failed to move to ({}, {})", x, y);
                return false;
            }
        }
        true
}

    fn click_mouse_windows(&self, button: &str) -> bool {
        use windows::Win32::UI::Input::KeyboardAndMouse::{MOUSEINPUT, SendInput, INPUT, INPUT_0};
        use windows::Win32::UI::Input::KeyboardAndMouse::{MOUSEEVENTF_LEFTDOWN, MOUSEEVENTF_LEFTUP, MOUSEEVENTF_RIGHTDOWN, MOUSEEVENTF_RIGHTUP, MOUSEEVENTF_MIDDLEDOWN, MOUSEEVENTF_MIDDLEUP};

        let (down, up) = match button.to_lowercase().as_str() {
            "left" => (MOUSEEVENTF_LEFTDOWN, MOUSEEVENTF_LEFTUP),
            "right" => (MOUSEEVENTF_RIGHTDOWN, MOUSEEVENTF_RIGHTUP),
            "middle" => (MOUSEEVENTF_MIDDLEDOWN, MOUSEEVENTF_MIDDLEUP),
            _ => {
                godot_error!("[InputInjector] unknown mouse button: {}", button);
                return false;
            }
        };

        let mi_down = MOUSEINPUT { dx: 0, dy: 0, mouseData: 0, dwFlags: down.0, time: 0, dwExtraInfo: 0 };
        let mi_up = MOUSEINPUT { dx: 0, dy: 0, mouseData: 0, dwFlags: up.0, time: 0, dwExtraInfo: 0 };
        let input_down = INPUT { Anonymous: INPUT_0 { mi: mi_down } };
        let input_up = INPUT { Anonymous: INPUT_0 { mi: mi_up } };
        let inputs = [input_down, input_up];

        unsafe {
            let sent = SendInput(&inputs, std::mem::size_of::<INPUT>() as i32);
            if sent == 0 {
                godot_error!("[InputInjector] SendInput failed for mouse button: {}", button);
                return false;
            }
        }

        true
}
}

// macOS implementation
#[cfg(target_os = "macos")]
impl InputInjector {
    fn type_text_macos(&self, text: &str) -> bool {
        // TODO: Implement using CGEvent
        godot_print!("Typing text (macOS): {}", text);
        true
    }

    fn press_key_macos(&self, keys: &[&str]) -> bool {
        // TODO: Implement using CGEvent
        godot_print!("Pressing keys (macOS): {:?}", keys);
        true
    }

    fn move_mouse_macos(&self, x: i32, y: i32) -> bool {
        // TODO: Implement using CGEvent
        godot_print!("Moving mouse (macOS): ({}, {})", x, y);
        true
    }

    fn click_mouse_macos(&self, button: &str) -> bool {
        // TODO: Implement using CGEvent
        godot_print!("Clicking mouse (macOS): {}", button);
        true
    }
}

// Linux implementation
#[cfg(target_os = "linux")]
impl InputInjector {
    fn type_text_linux(&self, text: &str) -> bool {
        // TODO: Implement using XTest extension
        godot_print!("Typing text (Linux): {}", text);
        true
    }

    fn press_key_linux(&self, keys: &[&str]) -> bool {
        // TODO: Implement using XTest extension
        godot_print!("Pressing keys (Linux): {:?}", keys);
        true
    }

    fn move_mouse_linux(&self, x: i32, y: i32) -> bool {
        // TODO: Implement using XTest extension
        godot_print!("Moving mouse (Linux): ({}, {})", x, y);
        true
    }

    fn click_mouse_linux(&self, button: &str) -> bool {
        // TODO: Implement using XTest extension
        godot_print!("Clicking mouse (Linux): {}", button);
        true
    }
}
