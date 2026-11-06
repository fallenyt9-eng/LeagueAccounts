//! Opt-in startup checkpoints for diagnosing a window that never appears.
//! The log is deliberately an allowlist: no account data, paths, URLs,
//! environment contents, panic payloads, or third-party errors are recorded.

use std::fs::{self, File, OpenOptions};
use std::io::Write;
use std::sync::{Mutex, OnceLock};
use std::time::{SystemTime, UNIX_EPOCH};

static FILE: OnceLock<Mutex<File>> = OnceLock::new();

#[derive(Clone, Copy)]
pub enum Stage {
    ProcessStarted,
    Panic,
    CoreLogReady,
    CoreLogUnavailable,
    UpdateCleanupBegin,
    UpdateCleanupComplete,
    ManagerInitBegin,
    ManagerInitComplete,
    ManagerInitFailed,
    AccountsLoadBegin,
    AccountsLoadComplete,
    AccountsLoadFailed,
    SettingsLoadBegin,
    SettingsLoadComplete,
    TauriBuildBegin,
    TauriBuildComplete,
    TauriBuildFailed,
    SetupBegin,
    WindowFound,
    WindowMissing,
    WindowShown,
    WindowShowFailed,
    SetupComplete,
    BootstrapCalled,
    EventLoopBegin,
    EventLoopExit,
}

impl Stage {
    fn code(self) -> &'static str {
        match self {
            Self::ProcessStarted => "process_started",
            Self::Panic => "panic",
            Self::CoreLogReady => "core_log_ready",
            Self::CoreLogUnavailable => "core_log_unavailable",
            Self::UpdateCleanupBegin => "update_cleanup_begin",
            Self::UpdateCleanupComplete => "update_cleanup_complete",
            Self::ManagerInitBegin => "manager_init_begin",
            Self::ManagerInitComplete => "manager_init_complete",
            Self::ManagerInitFailed => "manager_init_failed",
            Self::AccountsLoadBegin => "accounts_load_begin",
            Self::AccountsLoadComplete => "accounts_load_complete",
            Self::AccountsLoadFailed => "accounts_load_failed",
            Self::SettingsLoadBegin => "settings_load_begin",
            Self::SettingsLoadComplete => "settings_load_complete",
            Self::TauriBuildBegin => "tauri_build_begin",
            Self::TauriBuildComplete => "tauri_build_complete",
            Self::TauriBuildFailed => "tauri_build_failed",
            Self::SetupBegin => "setup_begin",
            Self::WindowFound => "window_found",
            Self::WindowMissing => "window_missing",
            Self::WindowShown => "window_shown",
            Self::WindowShowFailed => "window_show_failed",
            Self::SetupComplete => "setup_complete",
            Self::BootstrapCalled => "bootstrap_called",
            Self::EventLoopBegin => "event_loop_begin",
            Self::EventLoopExit => "event_loop_exit",
        }
    }
}

pub fn enabled() -> bool {
    option_env!("LEAGUEACCOUNTS_DIAGNOSTICS").is_some()
        || std::env::args_os().any(|arg| arg == "--diagnostics")
}

pub fn init() {
    if !enabled() {
        return;
    }
    let directory = std::env::temp_dir().join("LeagueAccounts-Diagnostics");
    if fs::create_dir_all(&directory).is_err() {
        return;
    }
    let stamp = unix_ms();
    let path = directory.join(format!("startup-{}-{stamp}.log", std::process::id()));
    let Ok(file) = OpenOptions::new().create_new(true).write(true).open(path) else {
        return;
    };
    if FILE.set(Mutex::new(file)).is_ok() {
        checkpoint(Stage::ProcessStarted);
    }
}

pub fn checkpoint(stage: Stage) {
    let Some(file) = FILE.get() else {
        return;
    };
    if let Ok(mut file) = file.lock() {
        let _ = writeln!(
            file,
            "unix_ms={} pid={} stage={}",
            unix_ms(),
            std::process::id(),
            stage.code()
        );
        let _ = file.flush();
    }
}

fn unix_ms() -> u128 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis()
}
