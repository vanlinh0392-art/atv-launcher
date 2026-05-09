# Changelog

ATV Launcher là một public fork cá nhân, xây trên nền:

- [etienn01/flauncher](https://gitlab.com/flauncher/flauncher)
- [osrosal/flauncher](https://github.com/osrosal/flauncher)

## 2026-05-09 - Official release 2026.05.012 tối ưu ổn định, bảo mật và log release

### Bảo mật và provisioning

- Tắt Android OS full-backup cho launcher để tránh backup ngoài luồng export/import có kiểm soát của app.
- Luồng `Cấp qua local ADB` không còn tự đưa launcher vào battery/device-idle whitelist; mục này chỉ còn là khuyến nghị cho Android box khi automation nền không ổn định.
- Trên TV tích hợp/live-TV, battery optimization được hạ xuống mức optional để người dùng không hiểu nhầm đây là quyền bắt buộc.

### RAM/CPU và hình nền

- Poster preview của video wallpaper giờ được trích bằng frame đã scale theo kích thước HOME, crop về 1080p tương đương và recycle bitmap native để giảm spike RAM với video 4K.
- App không có banner được cache negative riêng, tránh gọi native/PackageManager lặp lại khi HOME rebuild, focus hoặc scroll.
- Log wake-rearm video và log ADB/shell chi tiết được gate theo debug build, giảm spam logcat và tránh lộ command nội bộ ở release.

### Ổn định native và build

- Query danh sách app không còn nuốt `InterruptedException` / `ExecutionException`; lỗi được log rõ và không cache kết quả query dở.
- Network bridge chuyển khỏi API `NetworkInfo/getActiveNetworkInfo` cũ, dùng `NetworkCapabilities` cho trạng thái mạng hiện tại.
- Gradle khai báo Kotlin plugin đúng thứ tự trước Flutter plugin để loại cảnh báo KGP khi build.
- Thêm smoke script kiểm tra video wallpaper sau sleep/wake qua ADB.

### Kiểm chứng

- `flutter analyze --no-pub`: pass.
- `flutter test --no-pub`: pass toàn bộ suite.
- `flutter build apk --debug --target-platform android-arm --no-pub`: pass native compile, không còn warning KGP/deprecated.
- Release chính thức tiếp tục publish đúng 2 asset `atv-launcher-armeabi-v7a-release.apk` và `atv-launcher-arm64-v8a-release.apk`.

## 2026-05-09 - Official release 2026.05.011 sửa video nền sau sleep/wake

### Video wallpaper

- Native video wallpaper giờ nhận trực tiếp tín hiệu `SCREEN_ON`, `USER_PRESENT`, `DREAMING_STOPPED` và các wake action của Xiaomi TV để rearm playback khi TV thức dậy
- Luồng wake rearm gọi warm-up explicit để vượt guard `deferForegroundResume`, giúp Balanced/Smooth tự phát lại video nền mà không cần chọn lại thư mục video
- Thêm debounce wake event để tránh `SCREEN_ON` và `USER_PRESENT` kích hoạt nhiều lần liên tiếp
- Nếu playlist folder tạm thời trả rỗng ngay sau wake, controller retry có giới hạn để chờ MediaStore/SAF sẵn sàng thay vì đứng yên
- Vẫn tôn trọng `autoResume`, mode `Off`, video bị chặn bởi performance mode và suppression khi Settings đang mở

### Kiểm chứng

- `flutter analyze --no-pub`: pass
- `flutter test --no-pub test/providers/wallpaper_service_test.dart`: pass
- `flutter test --no-pub`: pass toàn bộ suite
- `flutter build apk --debug --target-platform android-arm --no-pub`: pass native compile

## 2026-05-07 - Official release 2026.05.010 chuyển GitHub mới và tối ưu RAM/CPU an toàn

### GitHub release mới

- Chuyển nguồn cập nhật chính thức sang repo public `vanlinh0392-art/atv-launcher`
- Updater không còn hardcode tài khoản GitHub cũ; workflow release tự lấy owner/repo từ `GITHUB_REPOSITORY`
- Khi TV không truy cập được repo cập nhật, màn cập nhật báo rõ trường hợp repo private, đổi tên, bị suspend hoặc bị chặn

### Tối ưu HOME không đổi trải nghiệm

- Balanced/Smooth giảm live backdrop blur trên HOME để hạ chi phí GPU/CPU idle, Quality vẫn giữ đường hiển thị đẹp nhất
- System bridge tách nhịp snapshot nóng/lạnh để HOME ít rebuild do các dữ liệu settings/provisioning không liên quan
- App card siết cache ảnh và decode theo kích thước hiển thị thực tế để giảm double-cache/double-decode

### Kiểm chứng

- `flutter analyze --no-pub`: pass
- Targeted updater tests: pass
- Release chính thức tiếp tục publish đúng 2 asset `atv-launcher-armeabi-v7a-release.apk` và `atv-launcher-arm64-v8a-release.apk`

## 2026-05-02 - Official release 2026.05.009 tối ưu CPU HOME, bridge hệ thống và tải ảnh app

### Tối ưu CPU không đổi trải nghiệm

- HOME bỏ cơ chế dựng `signature` dài cho toàn bộ launcher section, chuyển sang rebuild gating nhẹ hơn để giảm chi phí mỗi lần `notifyListeners`
- Dock HOME cache lại traversal node cho DPAD thay vì quét lại toàn bộ cây focus liên tục khi lên xuống trong danh sách app
- `AppCard` gom deferred image load về scheduler dùng chung, giữ ưu tiên tức thì cho item đang focus nhưng giảm burst timer khi HOME có nhiều card

### Native bridge và hình nền video

- `SystemBridgeService` giờ merge nhanh delta snapshot thay vì deep-merge toàn bộ map cho mọi event nhỏ
- Poll trạng thái hệ thống định kỳ được giãn từ `8s` lên `15s`, đồng thời tách TTL riêng cho cache provisioning và memory để giảm nhịp snapshot nặng
- Native `VideoWallpaperController` phát delta runtime trực tiếp khi `videoReady`, `videoSize`, `currentIndex` hoặc lỗi thay đổi, nên UI wallpaper vẫn phản ứng ngay dù polling nền nhẹ hơn

### Kiểm chứng

- `flutter analyze --no-pub`: pass
- `flutter test --no-pub`: pass toàn bộ suite
- `flutter build apk --debug --target-platform android-arm`: pass để xác nhận lại nhánh native/Java sau tối ưu CPU
- Release chính thức tiếp tục ship đúng 2 asset `atv-launcher-armeabi-v7a-release.apk` và `atv-launcher-arm64-v8a-release.apk`

## 2026-05-02 - Official release 2026.05.008 với ghi chú phát hành tiếng Việt và xác minh TV thực tế

### Hình nền ảnh và tối ưu RAM

- Luồng chọn `image wallpaper` giờ không còn copy nguyên file ảnh gốc vào runtime asset; native sẽ downsample, center-crop và chuẩn hóa ngay về khung HOME TV trước khi lưu preview dùng thật
- Wallpaper ảnh tĩnh giờ dọn `ImageCache` cũ khi đổi ảnh hoặc đổi mode, giúp giảm spike RAM do giữ đồng thời ảnh nền cũ và ảnh nền mới
- Render ảnh nền tĩnh bỏ `gaplessPlayback`, trong khi video/presenter fallback vẫn giữ nhịp chuyển an toàn như trước
- Mục tiêu của đợt này là giảm chi phí với ảnh nguồn 4K / 8K và giảm residency dư thừa mà không làm nền 1080p trên TV bị mềm thấy rõ

### Xác minh trên TV thực tế

- Kiểm chứng trên TV `192.168.1.111:5555` rằng luồng `Cấp qua local ADB` có thể tự khôi phục `VoiceBridgeAccessibilityService` cho launcher sau khi chủ động gỡ service khỏi `enabled_accessibility_services`
- Pane quyền trở về trạng thái ổn định ngay sau quick grant, cùng với log native `launcher_accessibility=restored`, `managed_accessibility=ok` và `grant_all_local_adb success=true`
- Tiếp tục xác nhận bản `armeabi-v7a` chạy đúng trên TV Xiaomi ABI `armeabi-v7a`, version `2026.05.008+23`

### Chẩn đoán hiện trường

- Audit `logcat` khi launcher đứng rảnh không phát hiện spam log từ `com.atv.launcher`; log ứng dụng chỉ còn mức rất hẹp ở `ResidentCoreService`
- Nguồn log lặp hiện quan sát được đến từ `com.xiaomi.mitv.remotecontroller.service` và pipeline codec hệ thống `media.codec` / `Utopia` / `MI3`, giúp tránh nhầm launcher là nguyên nhân trên máy thử nghiệm

### Phát hành

- GitHub official release tiếp tục chỉ publish 2 asset `atv-launcher-armeabi-v7a-release.apk` và `atv-launcher-arm64-v8a-release.apk`
- Release notes giờ lấy trực tiếp từ changelog tiếng Việt này để updater và log phân phối hiển thị cùng một nội dung
- Bản phát hành này chốt lại vết kiểm chứng trước khi ship cho `v7a` và `v8a` trên GitHub
- Hai asset release của bản này đã được rebuild lại sau patch tối ưu `image wallpaper`, verify đúng ABI và ký APK v2 thành công trước khi upload

Các thay đổi dưới đây mô tả riêng bản fork hiện tại, không lặp lại toàn bộ changelog của upstream.

## 2026-05-01 - Official release 2026.05.007 siết updater ABI, verify artifact và smoke runtime

### Updater và an toàn phát hành

- Session cập nhật giờ có state `resolved / degraded` cho ABI thiết bị, retry nhận ABI khi check release và hiện rõ khi đang rơi về fallback thay vì im lặng chọn asset mặc định
- Pane `Cập nhật` bổ sung chip/trạng thái `ABI thiết bị`, hiện cảnh báo khi updater đang dùng fallback và tiếp tục khóa đúng mapping `arm64-v8a -> v8a`, `armeabi-v7a -> v7a`
- Workflow `continuous-release` giờ verify APK sau build bằng script repo-local: package phải là `com.atv.launcher`, `versionName` phải khớp `pubspec.yaml`, ABI trong APK phải đúng với tên asset và thư mục official không được chứa `universal`

### Smoke và chẩn đoán runtime

- Thêm `scripts/smoke_update_abi_selection.py` để đọc ABI thật của TV qua `adb`, so với asset official hiện có và báo asset updater sẽ chọn
- Thêm `scripts/smoke_balanced_resume.py` để đẩy launcher xuống background bằng `Settings`, quay lại HOME và bắt log re-arm `Balanced` qua `adb logcat`
- Thêm log runtime hẹp cho nhánh re-arm video `Balanced`, giúp xác minh trên TV thật mà không cần build debug

### Kiểm thử

- `flutter analyze --no-pub`: pass
- `flutter test --no-pub`: pass toàn bộ

## 2026-05-01 - Official release 2026.05.006 với updater chọn đúng ABI và fix phát video nền

### Updater và phát hành

- Updater giờ đọc ABI thật của thiết bị để chọn đúng asset release: TV `arm64-v8a` ưu tiên `arm64-v8a`, fallback `armeabi-v7a`, rồi mới `universal`; TV `armeabi-v7a` ưu tiên `armeabi-v7a`, rồi `universal`
- Pane `Cập nhật` đã chuyển toàn bộ phần hiển thị size, subtitle, card chi tiết và luồng tải APK sang asset được chọn theo ABI máy, không còn luôn bám theo asset `v7a`
- Workflow `continuous-release` giờ build riêng 2 nhánh `android-arm` và `android-arm64`, chỉ publish 2 asset official `atv-launcher-armeabi-v7a-release.apk` và `atv-launcher-arm64-v8a-release.apk`
- Luồng build/release chính thức chịu được false-negative quen thuộc của `flutter build apk` bằng cách kiểm tra artifact APK thực tế trong `build/app/outputs/flutter-apk`

### Hình nền video và hiệu năng

- Sửa regression ở mode `Cân bằng`: khi người dùng đã set video nền, quay lại HOME hoặc đưa app từ background lên foreground sẽ explicit re-arm native playback để video tự phát lại ngay
- Giữ nguyên policy hiện tại của `Smooth`: vẫn chờ HOME usable rồi mới restore video nền
- Không đổi nhịp delayed startup của `Balanced` ở cold start, chỉ sửa luồng quay về HOME / foreground để tránh trường hợp poster đứng yên

### Cài đặt TV và DPAD

- Hoàn thiện tiếp điều hướng DPAD ở các pane `Quản lý trợ năng`, `Hiển thị / DPI`, `Chẩn đoán`, `System Core` và `Cập nhật` để focus không bị cụt ở action card cuối
- Thu gọn lại card/action layout ở các màn settings để giảm khoảng trống và giữ luồng điều hướng dọc ổn định hơn trên TV

### Kiểm thử và xác minh

- `flutter analyze --no-pub`: pass
- `flutter test --no-pub test/providers/wallpaper_service_test.dart`: pass
- `flutter test --no-pub test/launcher_update_client_test.dart`: pass
- `flutter test --no-pub test/widgets/settings/update_panel_page_test.dart`: pass
- `flutter build apk --release --target-platform android-arm --no-pub`: sinh `atv-launcher-armeabi-v7a-release.apk`
- `flutter build apk --release --target-platform android-arm64 --no-pub`: sinh `atv-launcher-arm64-v8a-release.apk`
- `adb install -r -d`: cài thành công bản `2026.05.006+21` lên TV `192.168.1.111:5555` với `primaryCpuAbi=armeabi-v7a`

## 2026-05-01 - Hoàn thiện điều hướng DPAD và phát hành official release mới

### Cài đặt TV

- Refactor pane `Cập nhật` sang session state tập trung để gom trạng thái check / tải / cài APK, làm gọn action card và giữ trạng thái rõ ràng hơn trên TV
- Sửa `Quản lý trợ năng`: bấm OK vào danh sách app được quản lý sẽ tự focus item đầu tiên, DPAD cuộn hết danh sách được và `UP` quay lại nút hiển thị danh sách
- Sửa `Chẩn đoán`: report trở thành vùng scroll riêng bằng DPAD, action card đầu pane được thu gọn đồng đều hơn
- Sửa `Hiển thị / DPI`: `UP` từ `Áp dụng` đi vào ô `DPI tùy chỉnh`, `DOWN` quay lại action chính để sửa nhanh bằng remote
- Sửa `System Core`: `Chạy heal ngay` không còn là điểm dừng cuối, snapshot core trở thành section focusable và phần hiển thị trạng thái đổi sang layout 2 cột gọn hơn để giảm khoảng trống

### Hệ thống và hiệu năng

- Đổi mode hiệu năng mặc định sang `Smooth`
- Đồng bộ lại metric grid và focus dọc ở các pane settings để các card summary / status không còn vỡ thành hàng lẻ khi điều hướng bằng DPAD

### Kiểm thử

- `flutter analyze --no-pub`: pass
- `flutter test --no-pub`: pass toàn bộ
- `flutter build apk --release --target-platform android-arm --no-pub`: Gradle tạo `atv-launcher-armeabi-v7a-release.apk`
- `adb install -r`: cài thành công bản `2026.05.005` lên TV `192.168.1.111:5555`

## 2026-05-01 - Tối ưu mode hiệu năng và khóa đúng luồng video sau `Tắt hiệu ứng`

### Hình nền và hiệu năng

- Chuẩn hóa policy video theo mode hiệu năng: `Balanced` và `Smooth` giữ video wallpaper nhưng dùng nhịp `poster-first + delayed-live`, còn `Tắt hiệu ứng` trở thành mode `no-video` thực sự
- Khi wallpaper video đang `mute`, native controller giờ tắt luôn audio renderer thay vì chỉ hạ volume về `0`, giúp giảm tải decode dư thừa
- `Tắt hiệu ứng` giờ tự fallback sang `poster` hoặc `gradient`, không warm-up texture video và không giữ nhánh `ExoPlayer` hoạt động trên HOME

### Khôi phục video

- Khi rời `Tắt hiệu ứng`, `Balanced` và `Smooth` tự khôi phục lại wallpaper video đã lưu trước đó
- Khi rời `Tắt hiệu ứng` sang `Quality`, launcher giữ nguyên `image/gradient`, xóa cờ restore chờ và không tự dựng lại video cho tới khi người dùng chọn lại trong `Hình nền & Media`
- Bổ sung đồng bộ startup cho non-video mode để native không còn giữ player cũ khi Flutter đã ở `image/gradient`

### Kiểm thử

- `flutter analyze --no-pub`: pass
- `flutter test --no-pub`: pass toàn bộ
- Test thực tế trên TV `192.168.1.111:5555`:
- `Off` chuyển `wallpaper_mode` sang `gradient`, bật `restore_candidate`, không còn `time_to_video_ready_request`
- `Off -> Balanced` và `Off -> Smooth` khôi phục lại `video` và có lại `time_to_video_ready_request`
- `Off -> Quality` giữ `gradient`, xóa `restore_candidate`, không còn thread `ExoPlayer` trong process launcher

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
