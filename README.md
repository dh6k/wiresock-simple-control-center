# WireSock Simple Control Center

**English** | [Tiếng Việt](README.vi.md)

A small collection of Windows `.bat` scripts for controlling **WireSock Secure Connect** through its CLI, while keeping important operations such as reconnects, profile switching, split tunneling changes, and network-lock cleanup guarded by timeouts and rollback logic.

There are two ways to use this repository:

- **`WireSock-Control-Center.bat`**: the all-in-one dashboard and menu.
- **`standalone/`**: individual BAT files for one specific task at a time.

## Features

- Turn the VPN on or off.
- Toggle **Global Split Tunneling**.
- Switch profiles and reconnect automatically.
- Open or close the WireSock GUI.
- Profile Manager: list, import, export, view, duplicate, rename, and delete profiles.
- Startup Monitor / Preflight before entering the Control Center.
- Check WireSock, CLI, PATH, config, profiles, and connection state.
- Configurable connection timeout, **15 seconds by default**, adjustable from **5 to 120 seconds**.
- Roll back profile/config changes when reconnecting fails.
- Clean up a stale network lock when Kill Switch is OFF.

---

# Requirements

- Windows 10 or Windows 11.
- Windows PowerShell.
- Administrator privileges when requested by the scripts.
- WireSock Secure Connect.
- **WinGet** is recommended if you want to use the bundled installer.
- **Git** is recommended if you want to clone the repository and update it with `git pull`.

The WireSock CLI is usually installed at:

```text
C:\Program Files\Wiresock Secure Connect\command-line\wiresock-connect-cli.exe
```

The Control Center also checks the common path variant where the product folder uses different capitalization for `WireSock`.

---

# Installation

## Option 1: Automatic installation with the bundled script

This is the easiest method on a machine that does not already have WireSock installed.

### Step 1: Download the repository

If Git is already installed:

```bat
git clone https://github.com/dh6k/wiresock-simple-control-center.git
cd wiresock-simple-control-center
```

If you do not use Git, download the repository as a ZIP from GitHub and **extract it completely** before running any BAT file. Do not run the scripts directly from inside the ZIP archive.

### Step 2: Run the installer

Open:

```text
standalone\Install-WireSock-and-Add-PATH.bat
```

The script requests Administrator privileges and then performs two tasks:

1. Installs WireSock with WinGet:

```bat
winget install NTKERNEL.WireSockVPNClient --accept-package-agreements --accept-source-agreements
```

2. Adds the WireSock CLI folder to the **System PATH** if it is not already present:

```text
C:\Program Files\Wiresock Secure Connect\command-line
```

The script avoids adding duplicate PATH entries and does not use PATH-writing methods that may truncate long environment variables.

### Step 3: Open a new terminal

After installation, close old CMD / PowerShell windows and open a new one so newly started applications receive the updated PATH.

Check the CLI with:

```bat
where wiresock-connect-cli.exe
```

If everything is correct, Windows should print the path to `wiresock-connect-cli.exe`.

You can also test the CLI directly:

```bat
wiresock-connect-cli status
```

### Step 4: Open WireSock at least once

It is recommended to open WireSock Secure Connect and create or import at least one profile before running the Control Center.

The Control Center reads some state from:

```text
C:\ProgramData\WireSock Foundation\WireSock Secure Connect\wiresock.config
```

If WireSock has never initialized its config file, or no profile exists yet, some fields may appear as `UNKNOWN` or `NOT FOUND`.

### Step 5: Start the Control Center

Double-click:

```text
WireSock-Control-Center.bat
```

The script requests UAC elevation when needed. After elevation, it runs the **Startup Monitor / Preflight** before showing the main menu.

---

## Option 2: Install WireSock manually

If you do not want to use the bundled installer BAT:

### 1. Install WireSock with WinGet

Open Terminal or PowerShell:

```bat
winget install NTKERNEL.WireSockVPNClient
```

### 2. Check the CLI

```bat
where wiresock-connect-cli.exe
```

If the CLI is not in PATH but exists in:

```text
C:\Program Files\Wiresock Secure Connect\command-line
```

you can still run:

```text
standalone\Install-WireSock-and-Add-PATH.bat
```

The installer detects that WireSock is already installed and continues with the PATH setup.

### 3. Clone the repository

```bat
git clone https://github.com/dh6k/wiresock-simple-control-center.git
cd wiresock-simple-control-center
```

### 4. Run a pre-check

You can run either:

```text
standalone\Check-Installation.bat
```

or:

```text
standalone\Startup-Monitor.bat
```

If the important checks report `OK`, run:

```text
WireSock-Control-Center.bat
```

---

# Updating

If you installed the project with Git:

```bat
cd wiresock-simple-control-center
git pull
```

Then launch the BAT file again as usual.

If you downloaded the repository as a ZIP, download the new version and replace the old folder. The following local settings file does not need to be copied back into the repository because it is recreated automatically:

```text
WireSock-Control-Center.ini
```

---

# Using the Control Center

The current dashboard looks like this:

```text
============================================================
                WireSock Control Center
============================================================

VPN Status       : Connected
WireSock GUI     : ON
Active Profile   : wg-SG-FREE-14
Profiles         : 6
Split Tunneling  : ON
Kill Switch      : OFF
Connect Timeout  : 15 seconds

[1] Toggle VPN
[2] Toggle Split Tunneling
[3] Switch Profile
[4] Check Installation Status
[5] Set Connection Timeout
[6] Toggle WireSock GUI
[7] Profile Manager
[8] Run Startup Monitor
[0] Exit
```

## [1] Toggle VPN

If the VPN is `Connected` or `Connecting`, the script disconnects it.

If the VPN is `Disconnected` or `NotConnected`, the script reads `ActiveConfig` and connects that profile.

The connection command is launched in the background and the script polls WireSock status independently, so the timeout can still work even if WireSock gets stuck in `Connecting`.

## [2] Toggle Split Tunneling

This toggles the actual global setting:

```xml
<EnableSplitTunnelingGlobally>True</EnableSplitTunnelingGlobally>
```

between `True` and `False`.

The script **does not modify your split-tunneling app or IP lists**.

If the VPN is currently connected, the flow is:

```text
disconnect
→ back up config
→ toggle setting
→ reconnect ActiveConfig
```

If reconnecting fails, the script attempts to restore the previous config.

## [3] Switch Profile

Profiles are displayed as a numbered menu:

```text
[1] wg-SG-FREE-14 [ACTIVE]
[2] wg-SG-FREE-3
[3] wg-SG-FREE-6
```

Selecting a new profile performs:

```text
disconnect current profile
→ change ActiveConfig
→ connect new profile
→ verify Connected
```

If the new profile does not connect before the timeout, the script cleans up the failed connection, restores the previous config, and attempts to reconnect the previous profile.

## [4] Check Installation Status

Quickly checks:

- WinGet.
- WireSock CLI.
- CLI availability in PATH.
- `wiresock.config`.
- WireSock GUI executable.
- VPN status.
- active profile.
- profile count.
- Split Tunneling.
- Kill Switch.
- connection timeout.

On a newly configured machine, this is the first place to look when something does not behave as expected.

## [5] Set Connection Timeout

Default:

```text
15 seconds
```

Allowed range:

```text
5 - 120 seconds
```

The setting is saved to:

```text
WireSock-Control-Center.ini
```

Example:

```ini
CONNECT_TIMEOUT=15
```

## [6] Toggle WireSock GUI

This only opens or closes the WireSock GUI process. It is not intended to stop the VPN service itself.

The script detects the WireSock GUI executable from the Start Menu or common installation folders, then tracks the corresponding process.

The standalone GUI toggle self-elevates when required so it can close a GUI process running at a higher privilege level.

## [7] Profile Manager

The menu includes:

```text
[1] List Profiles
[2] Import Profile (.conf)
[3] Export Profile
[4] View Profile
[5] Duplicate Profile
[6] Rename Profile
[7] Delete Profile
[8] Open Profiles Folder
[0] Back
```

Notes:

- `Import`: choose a `.conf` file using a file picker.
- `Export`: choose where to save the profile.
- `View`: export a temporary copy and open it in Notepad.
- `Duplicate`: export and import under a new name.
- `Rename`: create the new profile name, verify it, then remove the old profile.
- `Delete`: requires typing `DELETE` to confirm.
- The active profile cannot be renamed or deleted.

## [8] Run Startup Monitor

Runs the same preflight check that the Control Center performs at startup.

It is read-only by design and is not intended to change VPN, profile, or WireSock settings.

Logs are written to:

```text
logs\startup-YYYYMMDD-HHMMSS.log
```

---

# Standalone Scripts

If you do not want to open the all-in-one menu, each feature can also be run directly from `standalone/`.

| File | Purpose |
|---|---|
| `Install-WireSock-and-Add-PATH.bat` | Install WireSock with WinGet and add the CLI to System PATH |
| `Toggle-VPN.bat` | Turn the VPN on/off using ActiveConfig |
| `Toggle-Global-Split-Tunneling.bat` | Toggle Global Split Tunneling |
| `Switch-Profile.bat` | Switch profile and reconnect |
| `Check-Installation.bat` | Check installation, PATH, and runtime state |
| `Toggle-WireSock-GUI.bat` | Open/close the WireSock GUI |
| `Profile-Manager.bat` | Manage profiles |
| `Startup-Monitor.bat` | Run the preflight check independently |

The standalone BAT files are designed to run independently and handle their own working directory after the repository is cloned or moved to another location.

---

# Repository Layout

```text
wiresock-simple-control-center/
├─ WireSock-Control-Center.bat
├─ README.md
├─ README.vi.md
├─ .gitignore
├─ logs/                         # created by Startup Monitor
└─ standalone/
   ├─ Install-WireSock-and-Add-PATH.bat
   ├─ Toggle-VPN.bat
   ├─ Toggle-Global-Split-Tunneling.bat
   ├─ Switch-Profile.bat
   ├─ Check-Installation.bat
   ├─ Toggle-WireSock-GUI.bat
   ├─ Profile-Manager.bat
   └─ Startup-Monitor.bat
```

---

# Configuration File Used

WireSock Control Center reads:

```text
C:\ProgramData\WireSock Foundation\WireSock Secure Connect\wiresock.config
```

The main nodes used by the scripts are:

```xml
<ActiveConfig>wg-SG-FREE-14</ActiveConfig>
<EnableSplitTunnelingGlobally>True</EnableSplitTunnelingGlobally>
<EnableKillSwitch>False</EnableKillSwitch>
```

- `ActiveConfig`: the currently selected profile.
- `EnableSplitTunnelingGlobally`: the global Split Tunneling setting.
- `EnableKillSwitch`: read to decide how connection and network-lock cleanup should behave.

Before important config changes, the scripts create backups and use rollback logic where appropriate.

---

# Troubleshooting

## `wiresock-connect-cli.exe not found`

Check:

```bat
where wiresock-connect-cli.exe
```

If nothing is returned, run:

```text
standalone\Install-WireSock-and-Add-PATH.bat
```

Then open a new terminal.

## `The system cannot find the path specified`

First update the repository:

```bat
git pull
```

The current BAT files force their working directory to the script directory and include a fallback temporary directory to reduce path-related failures after UAC elevation or after cloning the repository into a different location.

If the error still occurs, run:

```text
standalone\Startup-Monitor.bat
```

to identify which expected path is missing.

## VPN stuck at `Connecting`

The Control Center has its own connection timeout. When it expires, the script attempts to clean up the failed tunnel and roll back profile/config changes made by the current operation.

You can change the timeout from:

```text
[5] Set Connection Timeout
```

## Internet remains blocked after a failed connection

If **Kill Switch was not intentionally enabled**, open CMD or Terminal as Administrator:

```bat
wiresock-connect-cli disconnect
wiresock-connect-cli reset-network-lock
```

Then reconnect a working profile.

If Kill Switch was intentionally enabled, do not treat `reset-network-lock` as a universal repair command because it removes the network lock.

## GUI toggle reports the wrong state or cannot close the GUI

Update the repository first:

```bat
git pull
```

The current standalone GUI toggle self-elevates and uses the actual WireSock GUI executable/process for detection and termination instead of blindly killing every process containing `wiresock` in its name.

---

# Quick Start

For a completely new machine:

```text
1. Clone or download the repository.
2. Run standalone\Install-WireSock-and-Add-PATH.bat.
3. Open WireSock and create/import a profile.
4. Run standalone\Check-Installation.bat.
5. Run WireSock-Control-Center.bat.
```

For a machine that already has WireSock:

```bat
git clone https://github.com/dh6k/wiresock-simple-control-center.git
cd wiresock-simple-control-center
WireSock-Control-Center.bat
```

To update later:

```bat
git pull
```

A small BAT window, a few number keys, and much less reason to open WireSock just to click switches that really should have had hotkeys in the first place.