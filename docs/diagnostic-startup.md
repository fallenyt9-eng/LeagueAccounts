League Accounts - startup diagnostic build

This build is for investigating an application that does not open.
It is separate from the production release. It will not self-update.

1. Extract every file from the GitHub Actions artifact to a folder.
2. Right-click Run-LeagueAccounts-Diagnostic.ps1 and choose Run with PowerShell.
   If execution policy blocks it, open PowerShell in the extracted folder and run:
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Run-LeagueAccounts-Diagnostic.ps1
   Only use this command for the downloaded script after verifying its source.
3. Wait for the runner to finish its 20-second observation, then close the application if it opened.
4. Find LeagueAccounts-Diagnostic-YYYYMMDD-HHMMSS on the Desktop.
5. Inspect the text files for private information before sharing the folder.

The application writes fixed startup stage codes into:
%TEMP%\LeagueAccounts-Diagnostics\startup-PID-TIMESTAMP.log

Existing ordinary application logs may also be copied from:
%APPDATA%\LeagueAccounts\logs

No credentials are read or exported. Windows event messages and file paths
may reveal usernames and system details; review before sharing.

Important: if the program fails before Rust main() (Windows loader failure),
there may be no startup stage file. The runner and Windows events remain useful.

Possible stages:
process_started, core_log_ready, update_cleanup_begin/complete,
manager_init_begin/complete/failed, accounts_load_begin/complete/failed,
settings_load_begin/complete, tauri_build_begin/complete/failed,
setup_begin, window_found/missing/shown/show_failed, bootstrap_called,
event_loop_begin/exit, panic.

Do not delete %APPDATA%\LeagueAccounts, reset Credential Manager, or remove
accounts during diagnosis.
