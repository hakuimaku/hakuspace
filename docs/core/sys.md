# Core System Scripts (src/core/sys)

The scripts inside `src/core/sys/` are the backbone of your desktop's lifecycle management. While other scripts handle aesthetics or quick utilities, these scripts manage how your computer sleeps, locks, shuts down, and handles user authentication.

They are designed to be completely Window Manager agnostic, meaning they work seamlessly whether you're logging into Hyprland, Niri, Mango, or Labwc!

Here is a detailed breakdown of each script:

## Power & Session Management

### `exit.sh` (The Safe Exit)
Have you ever logged out and had your system hang, or found zombie processes still running in the background?
- **What it does:** This script safely and gracefully exits your current session. Before killing your Window Manager, it targets essential apps (like VS Code, Firefox, Waybar, etc.) and gives them a polite `SIGTERM` signal so they can save their states. It then follows up with a `SIGKILL` to forcefully clean up any stubborn background processes, and clears out X11 socket files.
- **The Interface:** Before doing anything, it pops up a specialized Rofi menu displaying all your active processes sorted by RAM usage, allowing you to confirm the exit or cancel it.

### `shutdown.sh` (The Power Menu)
Your elegant replacement for typing terminal commands to reboot.
- **What it does:** Displays a clean, icon-based Rofi menu tailored for system power management (`shutdown.rasi`).
- **Options:** It allows you to select between Suspend (Sleep), Reboot, Poweroff, Hibernate, Lock Screen, or Log Out. Clicking any of these triggers the appropriate `systemctl` or local script command.

### `dpms_handler.sh` (Monitor Power Control)
Managing monitor power states varies wildly between different Window Managers. This script unifies them.
- **What it does:** It accepts `on` or `off` arguments to instantly power down or wake up your displays (DPMS).
- **How it works:** It detects your `XDG_CURRENT_DESKTOP` and translates the command into the correct protocol: `hyprctl` for Hyprland, `niri msg` for Niri, `mmsg` for Mango, or `wlr-randr` for Labwc.

## Idle & Lock Screen

### `idle_inhibit.sh` (The Smart Sleep Blocker)
There's nothing more annoying than your screen turning off while you're watching a video or listening to a podcast.
- **What it does:** This script acts as the brain for `hypridle`. When your system is inactive, `hypridle` asks this script if it's allowed to turn off the screen.
- **Audio Detection:** It actively checks your PulseAudio/PipeWire sink inputs. If it detects that audio is currently playing (and isn't muted or paused), it blocks the screen from sleeping.
- **Manual Toggle:** You can run it with `--toggle` to manually force the screen to stay on indefinitely, saving the state to a local file.

### `lock.sh` (The Smart Screen Locker)
Secures your computer when you step away.
- **What it does:** Uses `hyprlock` to lock your session. 
- **Dynamic Resolution:** It intelligently detects your monitor's current resolution (handling differences between Hyprland, Niri, Mango, and fallback sysfs paths). If your screen is `1920x1080` or larger, it loads the beautiful default lock screen. If you're on a smaller laptop screen, it automatically loads `hyprlock_tiny.conf` so the lock screen UI doesn't look squished!

## Boot & Authentication

### `polkit_start.sh` (The Privilege Manager)
Whenever an app needs root permissions (like GParted or a system updater), it needs an authentication window to ask for your password.
- **What it does:** Starts the MATE Polkit authentication agent (`polkit-mate-authentication-agent-1`) in the background on startup.
- **Cross-Distro Compatibility:** Because file paths differ across operating systems, this script dynamically hunts down the exact binary location whether you are running Arch Linux, Fedora, or NixOS, ensuring you never miss a password prompt.

### `welcome.sh` (The Greeting)
A small quality-of-life script.
- **What it does:** If `WELCOME_MSG=true` is set in your `~/hakucfg/setting.sh`, it waits two seconds after you log in and sends a friendly "Have a good day" system notification to greet you.


---
⬅️ **Previous:** [Theming Engine](theme.md) | **Next:** [Utilities](util.md) ➡️
