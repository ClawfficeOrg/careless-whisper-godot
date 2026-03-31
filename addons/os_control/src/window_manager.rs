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
    /// - process_id: i64 - process ID
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
                        let mut dict = VarDictionary::new();
                        dict.set("title", win.title);
                        dict.set("app_name", win.app_name);
                        dict.set("process_id", win.process_id);
                        dict.set("x", win.x);
                        dict.set("y", win.y);
                        dict.set("width", win.width);
                        dict.set("height", win.height);
                        let v = dict.to_variant(); arr.push(&v);
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
                        let mut dict = VarDictionary::new();
                        dict.set("title", win.title);
                        dict.set("app_name", win.app_name);
                        dict.set("process_id", win.process_id);
                        dict.set("x", win.x);
                        dict.set("y", win.y);
                        dict.set("width", win.width);
                        dict.set("height", win.height);
                        let v = dict.to_variant(); arr.push(&v);
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
                        let mut dict = VarDictionary::new();
                        dict.set("title", win.title);
                        dict.set("app_name", win.app_name);
                        dict.set("process_id", win.process_id);
                        dict.set("x", win.x);
                        dict.set("y", win.y);
                        dict.set("width", win.width);
                        dict.set("height", win.height);
                        let v = dict.to_variant(); arr.push(&v);
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
    /// PID as i64 to accommodate large PIDs on 64-bit Windows
    process_id: i64,
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
        use windows::Win32::Foundation::RECT;
        use windows::Win32::UI::WindowsAndMessaging::*;

        unsafe {
            let hwnd = GetForegroundWindow();
            // IsWindow is the canonical way to validate an HWND
            if !IsWindow(hwnd).as_bool() {
                return Err("No foreground window".to_string());
            }

            // Get window title
            let mut title_buf = [0u16; 512];
            let len = GetWindowTextW(hwnd, &mut title_buf);
            let title = String::from_utf16_lossy(&title_buf[..len as usize]);

            // Get window rect — check return value
            let mut rect = mem::zeroed::<RECT>();
            if let Err(e) = GetWindowRect(hwnd, &mut rect) {
                return Err(format!("GetWindowRect failed: {}", e));
            }

            // Get process ID
            let mut process_id = 0u32;
            GetWindowThreadProcessId(hwnd, Some(&mut process_id));

            // Derive app name from title (simplified heuristic)
            let app_name = title.split(" - ").last().unwrap_or(&title).to_string();

            Ok(WindowInfo {
                title,
                app_name,
                process_id: process_id as i64,
                x: rect.left,
                y: rect.top,
                width: rect.right - rect.left,
                height: rect.bottom - rect.top,
            })
        }
    }

    fn list_windows_windows(&self) -> Result<Vec<WindowInfo>, String> {
        use std::mem;
        use windows::Win32::Foundation::{BOOL, HWND, LPARAM, RECT};
        use windows::Win32::UI::WindowsAndMessaging::*;

        // Collect HWNDs via EnumWindows callback
        let mut hwnds: Vec<HWND> = Vec::new();
        let ptr = &mut hwnds as *mut _ as isize;

        unsafe extern "system" fn enum_cb(hwnd: HWND, lparam: LPARAM) -> BOOL {
            let hwnds = &mut *(lparam.0 as *mut Vec<HWND>);
            // Only visible top-level windows with a non-empty title
            if IsWindowVisible(hwnd).as_bool() && GetWindowTextLengthW(hwnd) > 0 {
                hwnds.push(hwnd);
            }
            BOOL(1) // continue enumeration
        }

        unsafe {
            if let Err(e) = EnumWindows(Some(enum_cb), LPARAM(ptr)) {
                return Err(format!("EnumWindows failed: {}", e));
            }
        }

        let mut results = Vec::with_capacity(hwnds.len());
        for hwnd in hwnds {
            unsafe {
                let mut title_buf = [0u16; 512];
                let len = GetWindowTextW(hwnd, &mut title_buf);
                if len == 0 {
                    continue;
                }
                let title = String::from_utf16_lossy(&title_buf[..len as usize]);

                let mut rect = mem::zeroed::<RECT>();
                if let Err(_e) = GetWindowRect(hwnd, &mut rect) {
                    continue; // skip windows whose rect we cannot read
                }

                let mut pid = 0u32;
                GetWindowThreadProcessId(hwnd, Some(&mut pid));

                let app_name = title.split(" - ").last().unwrap_or(&title).to_string();
                results.push(WindowInfo {
                    title,
                    app_name,
                    process_id: pid as i64,
                    x: rect.left,
                    y: rect.top,
                    width: rect.right - rect.left,
                    height: rect.bottom - rect.top,
                });
            }
        }
        Ok(results)
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
                process_id: window.owner_pid as i64,
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
                    process_id: window.owner_pid as i64,
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

        let (conn, screen_num) = xcb::Connection::connect(None)
            .map_err(|e| format!("Failed to connect to X server: {}", e))?;

        let setup = conn.get_setup();
        let _screen = setup
            .roots()
            .nth(screen_num as usize)
            .ok_or("Failed to get screen")?;

        // Simplified implementation - just return basic info
        // TODO: Use EWMH _NET_ACTIVE_WINDOW atom for a real implementation
        Ok(WindowInfo {
            title: "Unknown".to_string(),
            app_name: "Unknown".to_string(),
            process_id: 0_i64,
            x: 0,
            y: 0,
            width: 0,
            height: 0,
        })
    }

    fn list_windows_linux(&self) -> Result<Vec<WindowInfo>, String> {
        // TODO: Implement X11 window enumeration via xcb
        Ok(vec![])
    }
}
