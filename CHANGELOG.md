# Changelog

ATV Launcher là một public fork cá nhân của `xfire0392-netizen`, xây trên nền:

- [etienn01/flauncher](https://gitlab.com/flauncher/flauncher)
- [osrosal/flauncher](https://github.com/osrosal/flauncher)

Các thay đổi dưới đây mô tả riêng bản fork hiện tại, không lặp lại toàn bộ changelog của upstream.

## 2026-04-29 - Initial public ATV Launcher release

### System bridge

- Tích hợp native system bridge ngay trong launcher với provisioning, diagnostics và recovery
- Thêm Permission Center với checklist grant, wizard local ADB và trạng thái health
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
