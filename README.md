# ATV Launcher

ATV Launcher is a Flutter-based Android TV launcher focused on non-Google TVs, Xiaomi TV / Mi Box devices, and Android TV 9+ deployments that need deeper system control than a typical launcher.

This project starts from [`osrosal/flauncher`](https://github.com/osrosal/flauncher) tag `v2025.07.001` and turns it into a single integrated launcher APK with:

- a TV-first bottom-dock home screen
- local and playlist video wallpapers
- bilingual UI (`English` and `Vietnamese`)
- integrated system bridge for provisioning, voice, accessibility, DPI, DNS, and diagnostics
- no dependency on Google Play Services

## Why this fork exists

Most Android TV launchers handle app browsing well, but stop short when the target device is:

- a Xiaomi TV or Mi Box with aggressive boot/wake behavior
- a TV sold without Google certification
- a device that needs one-time ADB provisioning and then self-healing behavior
- a setup where voice remapping, accessibility recovery, DPI control, private DNS, or launcher recovery must live inside the launcher itself

ATV Launcher is built for that environment.

## Key capabilities

### Home experience

- Bottom-dock TV-first home layout with configurable `2 / 3 / 4` visible rows
- Auto-collapse dock with configurable collapsed state and idle timeout
- Adjustable card size, icon/media size, corner radius, row spacing, glass intensity, and category title visibility
- Row-centered DPAD scrolling tuned for remote control use
- Video wallpaper remains the visual focus instead of being hidden by a full-height grid

### Wallpaper and media

- `gradient`, `image`, and `video` wallpaper modes
- Video wallpaper from:
  - single file
  - multi-file playlist
  - folder playlist
- Sequential or shuffle playback
- Advance on completion or fixed interval switching
- Mute, dim, blur, fit mode, loop, and auto-resume controls
- Hybrid file access:
  - internal local video browser
  - MediaStore-based browsing
  - SAF fallback for file or folder selection
- Persisted URI access so media does not need to be granted again every time

### Voice and accessibility

- Integrated voice button remap with support for:
  - single press
  - double press
  - long press
  - double press then hold
- Learning mode for capturing the real remote key
- Voice launch order:
  - Google voice search activity if available
  - `android.speech.action.WEB_SEARCH`
  - `Intent.ACTION_ASSIST`
  - `Intent.ACTION_VOICE_COMMAND`
- Accessibility manager with repair and verification flows
- Managed accessibility service list with recovery support after boot or wake

### System bridge

- Integrated native services and receivers inside the launcher host
- Boot, wake, and Xiaomi-specific heal logic
- Resident core service and diagnostics
- Permission Center with local ADB flow and setup guidance
- ADB automation policies:
  - `off`
  - `adb_only`
  - `adb_and_wifi`
- Optional disable-on-sleep handling with throttled re-apply logic
- Home guard behavior to defend launcher foreground on devices that try to return to the stock home app

### Device control

- DPI read/apply/reset flow with multiple execution paths
- Private DNS read/apply/reset
- Battery optimization guidance
- Developer options deep links
- Provisioning checklist and grant health status

### Data and recovery

- Backup and restore for launcher configuration
- Stores layout, wallpaper, voice, accessibility, ADB policy, and system-related preferences
- Restore reports unresolved apps or missing media instead of silently failing

## Technical profile

- Package: `com.atv.launcher`
- Base: `osrosal/flauncher` tag `v2025.07.001`
- UI: Flutter
- Native host: Android / Java 17
- Min SDK: `28`
- Target SDK: `35`
- Release ABI: `armeabi-v7a` only
- Google Play Services: not required

## Settings areas

The integrated settings shell currently includes:

- Home & Layout
- Wallpaper & Media
- Voice & Search
- Profiles & Security
- Accessibility Manager
- System Core
- Display / DPI
- Network / Private DNS
- Permissions & Provisioning
- Backup & Restore
- Diagnostics
- Status Bar
- Applications

## Provisioning workflow

The intended deployment model is:

1. Install the launcher once with ADB.
2. Run one-time provisioning for elevated settings access.
3. Let the launcher verify, heal, and maintain state internally after boot, wake, or package replacement.

The repository includes a helper script:

```bash
python provision_atv_launcher.py --serial 192.168.1.111:5555
```

What the script can do:

- install the APK
- grant `WRITE_SECURE_SETTINGS`
- apply helpful appops
- whitelist battery optimization
- enable ADB or ADB Wi-Fi when requested
- verify final provisioning state

## Build instructions

### Requirements

- Flutter `3.24.5`
- Android SDK with platform tools
- Java `17`

### Install dependencies

```bash
flutter pub get
```

### Run tests

```bash
flutter analyze --no-pub
flutter test --no-pub
```

### Build debug APK

```bash
flutter build apk --debug --target-platform android-arm --no-pub
```

### Build release APK

```bash
flutter build apk --release --target-platform android-arm --no-pub
```

## Device focus

This launcher is primarily tuned for:

- Android TV 9 and above
- Xiaomi TV firmware behavior
- Mi Box style boot and wake cycles
- TV devices without Google services
- remote-first navigation from a DPAD handset

## Repository status

This repository is an actively customized product fork, not a minimal mirror of upstream FLauncher. Expect divergence in:

- settings UX
- system bridge code
- native Android services and receivers
- wallpaper/media architecture
- provisioning tooling
- TV-specific stability behavior

## License

This project remains under the upstream `GPL-3.0` license. See [LICENSE](LICENSE).

## Credits

- Original project: [etienn01/flauncher](https://gitlab.com/flauncher/flauncher)
- Fork base used for this work: [osrosal/flauncher](https://github.com/osrosal/flauncher)
