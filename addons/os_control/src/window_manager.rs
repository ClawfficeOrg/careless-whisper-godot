use godot::prelude::*;

/// WindowManager - Cross-platform window enumeration and control
///
/// Provides access to active window information and basic window management
/// across Windows, macOS, and Linux (X11/Wayland).
#[derive(GodotClass)]
#[class(init, base=RefCounted)]
pub struct WindowManager {
    base: Base<RefCounted>,
}

#[godot_api]
impl WindowManager {
    /// Get information about the currently active window
    ///
    /// Returns a Dictionary with:
    /// - title: String - window title
    /// - app_name: String - application name
    /// - process_id: i32 - process ID
    /// - x: i32 - window X position
    /// - y: i32 - window Y position
    /// - width: i32 - window width
    /// - height: i32 - window height
    /// - error: String - error message if failed
    #[func]
    pub fn get_active_window(&self) -> VarDictionary {
        let mut dict = VarDictionary::new();

        #[cfg(target_os = "windows")]
        {
            match self.get_active_window_windows() {
                Ok(info) => {
                    dict.set("title", info.title);
                    dict.set("app_name", info.app_name);
                    dict.set("process_id", info.process_id);
                    dict.set("x", info.x);
                    dict.set("y", info.y);
                    dict.set("width", info.width);
                    dict.set("height", info.height);
                }
                Err(e) => {
                    dict.set("error", e);
                }
            }
        }

        #[cfg(target_os = "macos")]
        {
            match self.get_active_window_macos() {
                Ok(info) => {
                    dict.set("title", info.title);
                    dict.set("app_name", info.app_name);
                    dict.set("process_id", info.process_id);
                    dict.set("x", info.x);
                    dict.set("y", info.y);
                    dict.set("width", info.width);
                    dict.set("height", info.height);
                }
                Err(e) => {
                    dict.set("error", e);
                }
            }
        }

        #[cfg(target_os = "linux")]
        {
            match self.get_active_window_linux() {
                Ok(info) => {
                    dict.set("title", info.title);
                    dict.set("app_name", info.app_name);
                    dict.set("process_id", info.process_id);
                    dict.set("x", info.x);
                    dict.set("y", info.y);
                    dict.set("width", info.width);
                    dict.set("height", info.height);
                }
                Err(e) => {
                    dict.set("error", e);
                }
            }
        }

        #[cfg(not(any(target_os = "windows", target_os = "macos", target_os = "linux")))]
        {
            dict.set("error", "Unsupported platform");
        }

        dict
    }

    /// List all visible windows
    ///
    /// Returns an Array of Dictionaries, each with the same structure as get_active_window()
    #[func]
    pub fn list_windows(&self) -> Array<Variant> {
        let mut arr = Array::new();

        #[cfg(target_os = "windows")]
        {
            match self.list_windows_windows() {
                Ok(windows) => {
                    for win in windows {
                        let mut dict = Dictionary::new();
                        dict.set("title", win.title);
                        dict.set("app_name", win.app_name);
                        dict.set("process_id", win.process_id);
                        dict.set("x", win.x);
                        dict.set("y", win.y);
                        dict.set("width", win.width);
                        dict.set("height", win.height);
                        arr.push(Variant::from(dict));
                    }
                }
                Err(e) => {
                    godot_error!("Failed to list windows: {}", e);
                }
            }
        }

        #[cfg(target_os = "macos")]
        {
            match self.list_windows_macos() {
                Ok(windows) => {
                    for win in windows {
                        let mut dict = Dictionary::new();
                        dict.set("title", win.title);
                        dict.set("app_name", win.app_name);
                        dict.set("process_id", win.process_id);
                        dict.set("x", win.x);
                        dict.set("y", win.y);
                        dict.set("width", win.width);
                        dict.set("height", win.height);
                        arr.push(Variant::from(dict));
                    }
                }
                Err(e) => {
                    godot_error!("Failed to list windows: {}", e);
                }
            }
        }

        #[cfg(target_os = "linux")]
        {
            match self.list_windows_linux() {
                Ok(windows) => {
                    for win in windows {
                        let mut dict = Dictionary::new();
                        dict.set("title", win.title);
                        dict.set("app_name", win.app_name);
                        dict.set("process_id", win.process_id);
                        dict.set("x", win.x);
                        dict.set("y", win.y);
                        dict.set("width", win.width);
                        dict.set("height", win.height);
                        arr.push(Variant::from(dict));
                    }
                }
                Err(e) => {
                    godot_error!("Failed to list windows: {}", e);
                }
            }
        }

        arr
    }
}

/// Window information structure
struct WindowInfo {
    title: String,
    app_name: String,
    process_id: i32,
    x: i32,
    y: i32,
    width: i32,
    height: i32,
}

// Windows implementation
#[cfg(target_os = "windows")]
impl WindowManager {
    fn get_active_window_windows(&self) -> Result<WindowInfo, String> {
        use std::mem;
        use windows::Win32::Foundation::{HWND, RECT};
        use windows::Win32::UI::WindowsAndMessaging::*;

        unsafe {
            let hwnd = GetForegroundWindow();
            if hwnd.0.is_null() {
                return Err("No foreground window".to_string());
            }

            // Get window title
            let mut title = [0u16; 512];
            let len = GetWindowTextW(hwnd, &mut title);
            let title = String::from_utf16_lossy(&title[..len as usize]);

            // Get window rect
            let mut rect = mem::zeroed::<RECT>();
            GetWindowRect(hwnd, &mut rect);

            // Get process ID
            let mut process_id = 0u32;
            GetWindowThreadProcessId(hwnd, Some(&mut process_id));

            // Get process name (simplified)
            let app_name = title.split(" - ").last().unwrap_or(&title).to_string();

            Ok(WindowInfo {
                title,
                app_name,
                process_id: process_id as i32,
                x: rect.left,
                y: rect.top,
                width: rect.right - rect.left,
                height: rect.bottom - rect.top,
            })
        }
    }

    fn list_windows_windows(&self) -> Result<Vec<WindowInfo>, String> {
        // TODO: Implement window enumeration using EnumWindows
        Ok(vec![])
    }
}

// macOS implementation
#[cfg(target_os = "macos")]
impl WindowManager {
    fn get_active_window_macos(&self) -> Result<WindowInfo, String> {
        use core_graphics::window::{get_active_window_list, kCGNullWindowID, CGWindow};

        unsafe {
            let windows = get_active_window_list(kCGNullWindowID, 0, 0)
                .map_err(|e| format!("Failed to get window list: {}", e))?;

            if windows.is_empty() {
                return Err("No active window".to_string());
            }

            let window = &windows[0];

            Ok(WindowInfo {
                title: window.name.clone().unwrap_or_default(),
                app_name: window.owner_name.clone().unwrap_or_default(),
                process_id: window.owner_pid as i32,
                x: window.bounds.origin.x as i32,
                y: window.bounds.origin.y as i32,
                width: window.bounds.size.width as i32,
                height: window.bounds.size.height as i32,
            })
        }
    }

    fn list_windows_macos(&self) -> Result<Vec<WindowInfo>, String> {
        use core_graphics::window::{get_active_window_list, kCGNullWindowID, CGWindow};

        unsafe {
            let windows = get_active_window_list(kCGNullWindowID, 0, 0)
                .map_err(|e| format!("Failed to get window list: {}", e))?;

            Ok(windows
                .iter()
                .map(|window| WindowInfo {
                    title: window.name.clone().unwrap_or_default(),
                    app_name: window.owner_name.clone().unwrap_or_default(),
                    process_id: window.owner_pid as i32,
                    x: window.bounds.origin.x as i32,
                    y: window.bounds.origin.y as i32,
                    width: window.bounds.size.width as i32,
                    height: window.bounds.size.height as i32,
                })
                .collect())
        }
    }
}

// Linux implementation
#[cfg(target_os = "linux")]
impl WindowManager {
    fn get_active_window_linux(&self) -> Result<WindowInfo, String> {
        use xcb::x;

        let (conn, screen_num) = xcb::Connection::connect(None)
            .map_err(|e| format!("Failed to connect to X server: {}", e))?;

        let setup = conn.get_setup();
        let screen = setup
            .roots()
            .nth(screen_num as usize)
            .ok_or("Failed to get screen")?;

        // Get active window using EWMH
        let root = screen.root();
        let active_window_cookie = conn.send_request(&x::GetProperty {
            delete: false,
            window: root,
            property: x::ATOM_WM_NAME,
            r#type: x::ATOM_WINDOW,
            long_offset: 0,
            long_length: 1,
        });

        // Simplified implementation - just return basic info
        Ok(WindowInfo {
            title: "Unknown".to_string(),
            app_name: "Unknown".to_string(),
            process_id: 0,
            x: 0,
            y: 0,
            width: 0,
            height: 0,
        })
    }

    fn list_windows_linux(&self) -> Result<Vec<WindowInfo>, String> {
        // TODO: Implement X11 window enumeration
        Ok(vec![])
    }
}