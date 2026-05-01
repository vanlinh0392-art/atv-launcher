# Changelog

ATV Launcher là một public fork cá nhân của `xfire0392-netizen`, xây trên nền:

- [etienn01/flauncher](https://gitlab.com/flauncher/flauncher)
- [osrosal/flauncher](https://github.com/osrosal/flauncher)

Các thay đổi dưới đây mô tả riêng bản fork hiện tại, không lặp lại toàn bộ changelog của upstream.

## 2026-05-01 - Official updater latest-release fix

### Updater

- Fixed `Check latest official release` so the launcher always picks the newest official GitHub release instead of getting stuck on an older one
- Added `no-cache` handling for GitHub release requests to reduce stale release responses on TV devices
- Accepted `Updater-Channel` markers even when older release notes wrapped the channel value in Markdown backticks
- Updated the GitHub release workflow footer to emit the updater channel as plain text for future releases
- When a fresh release check fails, the `Update` panel now clears stale release details instead of leaving the previous successful result on screen

### Settings UI

- Tightened the `summary / metrics header` layout used across right-side settings panes so metric cards keep a more even grid
- Added a minimum tile height plus anti-singleton wrapping in shared metrics grids to avoid one small orphan card on a trailing row
- Compacted the `Update` detail card and kept focus on the status region after checking releases so the pane no longer jumps and clips the top section on TV

### Verification

- Added coverage for latest-official-release sorting when GitHub returns releases in an unexpected order
- Added coverage for Markdown-formatted updater-channel markers in release bodies
- Added a regression test for failed re-checks so the UI does not keep showing an outdated release card
- Added a shared layout test so four summary cards do not collapse into an uneven 3+1 arrangement

## 2026-05-01 - Official updater + local ADB grant polish

### Updates and release flow

- Gọn lại pane `Cập nhật` với action grid đồng đều hơn, subtitle ngắn hơn và trạng thái dễ quét trên TV
- Giữ updater chỉ theo kênh `official release`, bỏ hoàn toàn debug build khỏi luồng kiểm tra trong launcher
- Bổ sung hiển thị tiến trình tải APK, trạng thái cài đặt và dọn nhanh các APK update đã tải

### Local ADB provisioning

- Sửa đường `Grant via local ADB` để không còn chạy network trên main thread
- Chuẩn hóa hướng dẫn local ADB theo `127.0.0.1:5555` và hiện rõ nhánh chờ authorize `unknown@unknown`
- Ổn định lại xử lý key local ADB để tránh reset/retry làm lệch fingerprint khi người dùng bấm `Allow`

## 2026-04-29 - Initial public ATV Launcher release

### System bridge

- Tích hợp native system bridge ngay trong launcher với provisioning, diagnostics và recovery
- Thêm Permission Center với checklist grant, wizard local ADB và trạng thái health
- Chuẩn hóa install flow public sang local ADB one-time trong app, bỏ hướng dẫn provisioning bằng script PC và bỏ ví dụ IP hard-code
- Bổ sung Resident Core, boot/wake heal flow và Xiaomi-specific recovery
- Thêm ADB automation policy, battery optimization guidance và home guard

### Voice, accessibility và control

- Tích hợp voice remap cho remote với learning mode
- Ưu tiên Google voice search, có fallback system voice actions
- Thêm Accessibility Manager với repair flow và managed package tracking

### Home, media và wallpaper

- Chuyển HOME sang bottom dock TV-first để lộ video wallpaper nhiều hơn
- Bổ sung auto-collapse dock, row-centered scrolling và glass UI có thể tùy chỉnh
- Thêm video wallpaper local, multi-file playlist và folder playlist
- Bổ sung điều khiển playback như sequential/shuffle, fixed interval, blur, dim, fit và mute

### Security, data và UX

- Thêm App Security với khóa app, ẩn app và bảo vệ settings bằng PIN
- Thêm backup / restore cấu hình launcher
- Thêm song ngữ English / Tiếng Việt
- Redesign settings shell theo kiểu master-detail TV-first

### Device controls

- Tích hợp Display / DPI read-apply-reset
- Tích hợp Network / Private DNS read-apply-reset
- Mở rộng diagnostics và provisioning snapshot cho thiết bị Android TV 9+
