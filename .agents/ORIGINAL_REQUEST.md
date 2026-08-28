# Original User Request

## 2026-08-27T23:43:23Z

This is a single self-contained fix; keep it small and focused.

Thực hiện kiểm toán và triển khai gói cải tiến toàn diện 4 phân hệ cho FLauncher Android TV, đặc biệt bảo đảm video nền khi đã được thiết lập trong cài đặt sẽ luôn tự động phát ngay lập tức (0-delay, 0-flicker, 0-freeze) khi quay về Home hoặc thức dậy từ chế độ ngủ trên mọi chế độ hiệu năng (Performance Modes: Balanced, Quality, Smooth).

Working directory: d:\mod\android\mapvoice\flauncher-v7a
Integrity mode: development

## Requirements

### R1. Instant Video Wallpaper on Home Return & Sleep Wake Across All Performance Modes
- Khi chế độ Video Wallpaper được kích hoạt (wallpaperMode == 'video'), video nền phải phát tức thì 0ms ngay khi Activity chuyển sang foreground/resumed hoặc nhận sự kiện đánh thức màn hình (screen_wake, STR_BOOT_COMPLETED, power_on).
- Loại bỏ hoàn toàn hiện tượng nháy/chớp ảnh nền mặc định (default_tv_wallpaper.jpg): Lớp render Flutter (_buildWallpaperLayer) phải giữ khung hình ấm trên SurfaceTexture hoặc hiển thị nền tối/gradient chuyển tiếp mượt mà, tuyệt đối không được render đè poster mặc định trong quá trình video re-arm.
- Bảo đảm cơ chế chạy ổn định, không bị chặn hay trì hoãn quá mức trên cả 3 chế độ: Balanced, Quality, Smooth.

### R2. Core Engine & Memory/Surface Lifecycle Hardening
- Rà soát và gia cố toàn bộ vòng đời của ExoPlayer và SurfaceTextureEntry trong VideoWallpaperController.java.
- Tự động phát hiện và phục hồi Surface Texture (Self-Healing Surface) khi TV sleep/wake nhiều lần hoặc chuyển đổi ứng dụng đồ họa nặng (YouTube 4K, Kodi), triệt tiêu lỗi omxError 0x80001013 và hiện tượng đen màn hình.
- Dọn dẹp bộ nhớ đệm hình ảnh và giải phóng tài nguyên triệt để khi chuyển đổi giữa các loại hình nền.

### R3. TV D-Pad Remote Navigation & State Preservation
- Chuẩn hóa điều hướng Focus cho Remote TV trên toàn bộ màn hình Home và các Panel cài đặt (SettingsFocusFrame, RowByRowTraversalPolicy).
- Bảo đảm khi di chuyển D-Pad tốc độ cao hoặc cuộn danh sách dài, focus không bị trượt ra ngoài và vị trí cuộn trang (PageStorageKey) được lưu giữ nguyên vẹn.

### R4. AI Voice & Real-Time News Broadcaster Fast-Path
- Tối ưu hóa luồng xử lý giọng nói thông minh (SmartVoiceDispatcher.java) và Trợ lý đọc tin tức Việt Nam (VietnamNewsProvider.java / AiVoiceAssistantClient.java).
- Bổ sung cơ chế Dual-Cache (RAM Cache + fallback an toàn) giúp phản hồi phát thanh tin tức tức thì ngay cả khi mạng TV chập cheer.

## Verification Resources
- Test suite chính thức của dự án: lutter test (chứa 282+ bài kiểm thử tích hợp và kiểm thử giao diện).
- Kịch bản kiểm thử vòng đời đánh thức TV: scripts/smoke_wallpaper_wake.py.
- Lệnh kiểm tra phân tích tĩnh: lutter analyze.

## Acceptance Criteria

### Video Wallpaper & Performance Modes
- [ ] Trở về màn hình Home từ app ngoài: Video nền bắt đầu chuyển động ngay lập tức, 0% chớp ảnh nền mặc định.
- [ ] Bật/tắt màn hình TV hoặc thức dậy từ chế độ ngủ: Video nền tự động resume liền mạch không lỗi codec.
- [ ] Chuyển đổi qua lại giữa các chế độ hiệu năng (Balanced, Quality, Smooth) giữ nguyên trạng thái video và không gây xung đột tài nguyên.

### System Stability & Test Suite
- [ ] 100% test cases trong lutter test vượt qua màu xanh (All tests passed!).
- [ ] lutter analyze không có bất kỳ lỗi biên dịch nghiêm trọng nào.
- [ ] Build thành công file APK release armeabi-v7a (lutter build apk --release --target-platform=android-arm --split-per-abi) với dung lượng tối ưu ~22.8 MB.
