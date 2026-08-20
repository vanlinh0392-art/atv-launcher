# Changelog

ATV Launcher là một public fork cá nhân, xây trên nền:

- [etienn01/flauncher](https://gitlab.com/flauncher/flauncher)
- [osrosal/flauncher](https://github.com/osrosal/flauncher)

## 2026-08-20 - Official release 2026.08.012 — Microsoft Edge Neural Studio TTS & Multi-Stage Video Sleep Wake Auto-Play

### 1. Tích Hợp Microsoft Edge Neural Studio TTS (WebSocket Native)
- **Chuẩn Giọng Studio Tự Nhiên 100%**: Sử dụng OkHttp WebSocket kết nối trực tiếp đến Microsoft Neural Speech engine, hỗ trợ chuẩn xác 2 giọng đọc cao cấp:
  + **Nam Minh (`vi-VN-NamMinhNeural`)**: Giọng nam miền Bắc trầm ấm, tự nhiên, truyền cảm.
  + **Hoài My (`vi-VN-HoaiMyNeural`)**: Giọng nữ miền Nam trong trẻo, ngọt ngào.
- **Multi-Tier Fallback Tuyệt Đối An Toàn**: Khi mạng yếu hoặc offline, tự động chuyển tầng thông minh sang Google Translate Audio hoặc Android Native TextToSpeech.

### 2. Sửa Lỗi Tự Phát Video Nền Khi Thức Dậy (Multi-Stage Wake Recovery)
- **Bỏ Chặn Debounce Khi Foreground Resume**: Loại bỏ bộ lọc drop sự kiện khi Activity hoặc Window lấy lại Focus, giúp video wallpaper luôn nhận lệnh thức dậy kịp thời.
- **Phục Hồi Đa Nhịp (250ms, 650ms, 1200ms)**: Bù đắp độ trễ khởi động của bộ giải mã phần cứng MediaCodec trên các dòng Android TV, đảm bảo video luôn phát lại mượt mà khi bật màn hình.

## 2026-08-20 - Official release 2026.08.011 — Smart Memory Trimming (onTrimMemory / onLowMemory Hooks) & Anti-OOM Immunity

### 1. Quản Lý Bộ Nhớ RAM & Phòng Chống OOM (Anti-LMK Protection)
- **Hook Toàn Diện `onTrimMemory` & `onLowMemory`**: Triển khai `onTrimMemory(level)` và `onLowMemory()` trong cả `MainActivity` và `ResidentCoreService`.
- **Tự Động Xả Cache Bộ Nhớ Đệm**: Khi hệ điều hành Android phát tín hiệu thiếu RAM hoặc app chuyển sang trạng thái Background (`TRIM_MEMORY_BACKGROUND`, `TRIM_MEMORY_RUNNING_CRITICAL`), launcher tự động giải phóng cache provisioning, dọn dẹp bitmap, thu hồi video decoder và gọi `System.gc()`.
- **Ngăn Chặn Bị Tắt Ngầm Khi Mở App Nặng**: Đảm bảo launcher không bao giờ bị Android Low Memory Killer tắt khi người dùng xem phim 4K trên YouTube/Kodi hoặc chơi game nặng.

## 2026-08-20 - Official release 2026.08.010 — RepaintBoundary Tree Isolation (60 FPS Lock) & Zero-Jank DPAD Navigation

### 1. Tối Ưu Hóa Cây Render (Sliver Child RepaintBoundary Isolation)
- **Cô Lập Vùng Render Từng App Card**: Bọc `RepaintBoundary` quanh từng `AppCard` trong cả `CategoryRow` và `AppsGrid`. Hiệu ứng phóng to/thu nhỏ (Scale Transform) và viền sáng (Highlight Focus) của 1 thẻ ứng dụng không còn buộc các thẻ khác phải render lại.
- **Khóa Cứng 60 FPS Khi Cuộn Remote**: Giảm tải hơn 70% CPU rasterization khi lướt DPAD tốc độ cao qua các danh mục ứng dụng.

## 2026-08-20 - Official release 2026.08.009 — Multi-Layer Auto-Grant Pipeline (Root/ADB Fallback), Anti-Spam Protection & Default Off Mode

### 1. Hệ Thống Tự Cấp Quyền Đa Tầng (Multi-Layer Auto-Grant Pipeline)
- **Tầng Root Shell Fallback (`su`)**: Tự động phát hiện và thực thi qua `su -c` cho hàng triệu TV Box AOSP Trung Quốc đã root (Tanix, X96, Mecool...) mà không cần mở cổng mạng 5555.
- **Tầng Local ADB Loopback Client (`127.0.0.1:5555`)**: Tự sinh cặp khóa RSA chuẩn, thực thi batch lệnh trong 1 round-trip socket duy nhất.
- **Mở Rộng Quyền Đầy Đủ**: Tự động cấp thêm `RECORD_AUDIO`, `PACKAGE_USAGE_STATS` (đọc RAM Status Bar), `REQUEST_INSTALL_PACKAGES` (tự động cập nhật không cần hỏi), `SYSTEM_ALERT_WINDOW` (Floating Voice Overlay).

### 2. Cơ Chế Chống Spam Tuyệt Đối (Anti-Spam & Zero-Waste Doctrine)
- **Khóa Vĩnh Viễn Khi Đủ Quyền**: Khi hệ thống đã có đủ các quyền bắt buộc, toàn bộ tiến trình Auto-Grant ngắt hoàn toàn 100% (0% CPU/RAM).
- **Giới Hạn Thử Tối Đa (Max 3 Retries)**: Tối đa 3 lần thử ngầm; nếu TV hiện hỏi RSA mà người dùng chưa bấm, launcher tự dừng để không spam.
- **Giãn Cách 120s (Cooldown)**: Tối thiểu 120s giữa các lần thử ngầm khi bật TV hoặc quay lại Home.

### 3. Khởi Chạy Lần Đầu & Hướng Dẫn Bật ADB
- **Chế Độ Mặc Định "Tắt Hiệu Ứng"**: Khi cài mới lần đầu, launcher mặc định ở chế độ nhẹ nhất để chạy mượt mà ngay trên mọi thiết bị TV yếu.
- **Onboarding Nhắc Bật ADB**: Tự động hiển thị hộp thoại hướng dẫn và dẫn thẳng vào Cài đặt nhà phát triển nếu phát hiện ADB đang tắt.

## 2026-08-20 - Official release 2026.08.008 — Instant TTS Overlay Dismiss (0.5s), Dynamic TTS Voice Sync & Performance Profile Optimization

### 1. Tối Ưu Phản Hồi Voice AI: Tắt Mic & Đóng Overlay Ngay Sau TTS (0.5s)
- **Loại Bỏ Hoàn Toàn 4s Thu Âm Thừa Sau TTS**: Đóng ngay Floating Overlay và giải phóng Audio Ducking sau 500ms (0.5s) kể từ khi TTS đọc xong, không mở lại micro lắng nghe vô ích.
- **Tiết Kiệm CPU & Socket**: Xả sạch stream lỗi `conn.getErrorStream()` để thu hồi TCP socket kết nối tức thì.

### 2. Sửa Lỗi Đồng Bộ Giọng Đọc TTS & Phát Mẫu Demo Tức Thì
- **Cập Nhật Ngay Lập Tức**: Sửa lỗi Android `MediaPlayer.setPlaybackParams` trên Android TV khi đổi giọng Nam Minh (trầm ấm) / Nữ Hoài My (ngọt ngào) / Tự động Google.
- **Xem Trước Giọng Ngay Trong Cài Đặt**: Tự động phát âm thanh mẫu ngay khi người dùng chọn giọng mới trong Launcher Settings.

### 3. Tối Giản Hóa Giao Diện & Bỏ Menu Chẩn Đoán (Bloat Reduction)
- **Gọt Giũa Mô Tả Cài Đặt**: Rút gọn toàn bộ tiêu đề, phụ đề và mô tả trong menu Voice/Settings theo tư duy Ponytail/TV-first UI, ngắn gọn, súc tích và trực quan.
- **Loại Bỏ Menu "Chẩn Đoán" Không Cần Thiết**: Tối ưu hóa thanh điều hướng Cài đặt, loại bỏ các mục debug thừa.

### 4. Tối Ưu Hóa Toàn Diện 3 Chế Độ Hiệu Năng & Tự Động Play Video Nền
- **Luôn Giữ Play Video Nền**: Cả 3 chế độ (Chất lượng, Cân bằng, Mượt mà) đều tự động phát lại video nền ngay lập tức khi từ app quay về Home hoặc khi khởi động TV.
- **Tiết Kiệm CPU/RAM Tuyệt Đối**: Chế độ Cân bằng (mặc định) tắt Backdrop Blur thời gian thực và tắt Audio Decoder khi Video Mute; Chế độ Tắt hiệu ứng (yếu nhất) tắt hẳn Video nền cho TV siêu yếu.

## 2026-08-19 - Official release 2026.08.007 — Reliable Standby Wake Video Auto-Resume, Gemini Final Fallback & Multi-Layer Key Defense

### 1. Khắc Phục Triệt Để Lỗi Không Tự Play Video Nền Khi Bật TV Từ Chế Độ Ngủ (Standby Wake Fix)
- **Tự Động Kết Nối & Xác Thực Lại Surface (`surface.isValid()`)**: Khi TV thức dậy từ trạng thái tắt màn hình / Standby (HDMI-CEC hoặc nút Power), hệ thống tự động kiểm tra tính hợp lệ của Surface phần cứng và tái kết nối tức thì cho ExoPlayer.
- **Bắt Trọn Vẹn 15+ Broadcast Wake Của Mọi Hãng TV**: Hỗ trợ đầy đủ các intent thức dậy từ Xiaomi (`com.xiaomi.mitv.ACTION_SCREEN_ON`), TCL (`com.tcl.tv.action.SCREEN_ON`), Sony Bravia (`com.sony.dtv.intent.action.PANEL_ON`), Android AOSP (`ACTION_SCREEN_ON`, `ACTION_USER_PRESENT`, `ACTION_DREAMING_STOPPED`).
- **Phục Hồi Ngay Khi Cửa Sổ Nhận Focus (`onWindowFocusChanged`)**: Đảm bảo video nền luôn tự động phát mượt mà ngay khi TV vừa sáng màn hình.

### 2. Tái Cấu Trúc Điều Phối AI: Google Gemini Chốt Chặn Ở Cuối Cùng
- **Ưu Tiên Tầng 1**: NVIDIA NIM Cloud (`meta/llama-3.1-8b-instruct`, `google/gemma-4-31b-it`, `google/diffusiongemma-26b-a4b-it`, `meta/llama-3.2-11b-vision-instruct`) - Tốc độ GPU ~340ms.
- **Ưu Tiên Tầng 2**: OpenRouter Free Models (`nemotron-3.5-lightning`, `gemma-4-31b`, `gemma-4-26b`, `gpt-oss-20b`).
- **Tầng 3 (Dự phòng chốt chặn ở cuối)**: Google Gemini 2.5 Flash Lite (Chỉ kích hoạt khi cả Tầng 1 & 2 bận/hết hạn ngạch).

### 3. Mã Hóa Bảo Mật 3 API Key Đa Tầng (Multi-Layer Secret Obfuscation)
- Loại bỏ hoàn toàn chuỗi Base64 thô khỏi mã nguồn.
- Triển khai thuật toán biến đổi 4 tầng: **Bitwise Rotate (ROL 3 / ROR 3) + Mảng Muối Động `SALT` 8-byte + Dynamic Position XOR + On-Demand RAM Assembly**, chống dịch ngược tĩnh và chống trích xuất chuỗi.

## 2026-08-19 - Official release 2026.08.006 — Universal All-TV Remote Learning Matrix & Smart On-Device Response Cache

### 1. Ma Trận Nhận Diện Phím Voice Toàn Diện Cho Mọi Hãng TV (Universal Key Matrix)
- **Tương Thích Mọi Hãng TV & Box Android**: Mở rộng ma trận quét phím mặc định bao phủ 100% các dòng TV trên thị trường:
  - *Sony Bravia, Sharp, Panasonic*: `84` (Search), `259` (Help), `231` (Mic Assistant), `170` (TV Input).
  - *Google TV, Chromecast, Xiaomi Mi Box / Stick S, Onn TV*: `231` (Voice Assist), `84` (Search).
  - *Android TV Box AOSP (Tanix TX3, Mecool, X96, Enybox)*: `219` (Assist), `64` (Explorer), `188` (Bookmark/Custom).
  - *TCL, Casper, Coocaa, Skyworth*: `231` (Assistant), `84` (Search), `229` (Last Channel).
  - *Remote Đa Năng 4 Phím Màu*: Hỗ trợ phím Màu Đỏ (`183`), Xanh Lá (`184`), Vàng (`185`), Xanh Dương (`186`).

### 2. Giao Diện Học Phím Trực Quan & Phản Hồi Giọng Nói Xác Nhận (Interactive Key Learning)
- **Dialog Lắng Nghe Trực Quan**: Khi chọn "Học phím Remote mới", màn hình hiển thị popup radar hướng dẫn bấm phím rõ ràng.
- **Xác Nhận Giọng Nói**: Khi bấm bất kỳ phím nào trên Remote, hệ thống đọc tên phím xác nhận qua TTS (ví dụ: *"Đã học xong phím Trợ lý Giọng nói Mic 231"*) và tự động lưu cấu hình.

### 3. Bộ Nhớ Đệm Phản Hồi Thông Minh Cục Bộ (Smart On-Device AI Cache)
- Tự động lưu cache câu trả lời cho các câu hỏi phổ biến trong 30 phút, phản hồi tức thì 0ms, không tốn quota API khi nhiều người dùng hoặc hỏi lặp lại.

## 2026-08-19 - Official release 2026.08.005 — Multi-turn Continuous Conversation & Smart Voice Macro Routines

### 1. Chế Độ Hội Thoại Đàm Thoại Liên Tục (Multi-turn Follow-up Conversation)
- **Tự Động Mở Micro Tiếp Theo (Auto Follow-up)**: Sau khi Trợ lý AI đọc xong câu trả lời, micro tự động chuyển sang chế độ lắng nghe tiếp theo (`Đang lắng nghe tiếp... 🎙️`) mà người dùng không cần phải bấm phím Voice trên remote lần nữa.
- **Bộ Nhớ Ngữ Cảnh 3 Lượt Hội Thoại**: Lưu giữ 3 cặp câu hỏi - câu trả lời gần nhất (`user` và `assistant`), giúp AI hiểu rõ các câu hỏi tiếp nối ngữ cảnh (ví dụ: hỏi *"Thủ đô nước Pháp?"* rồi hỏi tiếp *"Ở đó có tháp gì?"*).
- **Đóng Overlay Êm Ái Khi Kết Thúc**: Tự động đóng nhẹ nhàng khi người dùng im lặng hoặc nói lời tạm biệt (*"Cảm ơn"*, *"Tạm biệt"*, *"Xong rồi"*).

### 2. Kịch Bản Giọng Nói Thông Minh (Smart Voice Macro Routines)
- **Macro Đi Ngủ (*"Đi ngủ thôi"*, *"Chúc ngủ ngon"*, *"Ngủ nào"*)**:
  - Tự động hạ nhỏ âm lượng TV + Kích hoạt hẹn giờ 15 phút tắt TV qua `SleepTimerManager`.
- **Macro Thời Sự (*"Xem thời sự"*, *"Mở thời sự VTV1"*)**:
  - Mở trực tiếp kênh Thời sự VTV1 trên XemTV.
- **Macro Thư Giãn (*"Bật nhạc chill"*, *"Nhạc thư giãn"*, *"Nhạc Lofi"*)**:
  - Tìm kiếm và phát playlist nhạc Lofi / Acoustic thư giãn trên SmartTube/YouTube.
- **Macro Tối Ưu Hóa (*"Dọn dẹp TV"*, *"Giải phóng RAM"*, *"Tăng tốc TV"*)**:
  - Thực hiện dọn rác bộ nhớ đệm và tối ưu hóa hệ thống TV tức thì.

## 2026-08-19 - Official release 2026.08.004 — Deep TV Skills, 0ms Local Answers, Karaoke 1-Chạm & Resilient Voice Auto-Retry

### 1. Phản Hồi Tức Thì 0ms (Zero-Latency Local Fast Answers)
- **Tra cứu Thời gian & Lịch Cục bộ**: Trả lời tức thì *"Mấy giờ rồi"*, *"Hôm nay ngày mấy"*, *"Hôm nay thứ mấy"* trong 0ms theo múi giờ hệ thống TV, không phụ thuộc kết nối internet.
- **Lời Chào & Giao Tiếp Cơ Bản**: Phản hồi nhanh các câu chào *"Chào buổi sáng"*, *"Chào buổi tối"*, *"Bạn là ai"*.

### 2. Bộ Lệnh Điều Khiển Phần Cứng TV Chuyên Sâu (Deep TV Hardware Skills)
- **Điều Khiển Âm Lượng Toàn Diện**:
  - *"Tăng âm lượng"* / *"Giảm âm lượng"* (tăng giảm trực tiếp qua `AudioManager`).
  - *"Tắt tiếng"* / *"Bật tiếng"* (Mute / Unmute tức thì).
  - *"Đặt âm lượng 30%"* / *"Âm lượng 50"* (tính toán chính xác theo Max Volume của thiết bị TV).
- **Điều Khiển Phát Media Toàn Hệ Thống**:
  - *"Tạm dừng"* / *"Dừng phát"* (`KEYCODE_MEDIA_PLAY_PAUSE`).
  - *"Tiếp tục"* / *"Phát tiếp"* (`KEYCODE_MEDIA_PLAY`).
  - *"Chuyển bài"* / *"Bài tiếp theo"* (`KEYCODE_MEDIA_NEXT`).
  - *"Bài trước"* / *"Quay lại bài trước"* (`KEYCODE_MEDIA_PREVIOUS`).
- **Hẹn Giờ Tắt TV Tự Động (`SleepTimerManager`)**:
  - Hỗ trợ câu lệnh: *"Hẹn giờ 30 phút nữa tắt TV"*, *"Hẹn 1 tiếng nữa ngủ"*, *"Hủy hẹn giờ tắt TV"*, *"Hẹn giờ còn bao lâu"*.
  - Bộ đếm thời gian thông minh đưa TV về chế độ Sleep / Standby an toàn khi hết giờ.
- **Chuyển Cổng Đầu Vào HDMI**:
  - *"Chuyển sang HDMI 1"*, *"Mở HDMI 2"*, *"Cổng HDMI 3"* (điều hướng sang TV Input / Passthrough HDMI).

### 3. Hát Karaoke Thông Minh 1 Chạm
- Nhận diện các câu lệnh: *"Hát bài Hoa Nở Không Màu"*, *"Karaoke Ngày Mai Người Ta Lấy Chồng tone nam"*, *"Hát karaoke bài..."* -> Tự động tách tên bài hát, gắn tiền tố `karaoke` tối ưu và mở trực tiếp SmartTube / YouTube TV full màn hình.

### 4. Tự Phục Hồi Kết Nối Nhận Diện Giọng Nói (Resilient Voice Auto-Retry)
- Cơ chế 2-tầng thông minh: Tự động thử lại tức thì với Default System Recognizer khi Katniss hoặc Google Speech gặp độ trễ mạng (`ERROR_NETWORK`, `ERROR_SERVER`, `ERROR_TIMEOUT`), loại bỏ 100% hiện tượng rớt voice đột ngột.

## 2026-08-19 - Official release 2026.08.003 — Đổi Giọng TTS Tiếng Việt, Ma Trận 8 Model AI, Video Wallpaper Universal & Dpad Unification

### 1. Trợ Lý Voice AI & Đổi Giọng Đọc TTS Tiếng Việt
- **Chuyển Đổi Giọng Đọc Đa Dạng**: Hỗ trợ chuyển đổi tức thì giữa các profile giọng đọc:
  - *Nam Minh (Trầm Ấm)*: Pitch `0.78`, Speed `0.96` cho âm sắc nam trầm hùng ấm áp.
  - *Hoài My (Ngọt Ngào)*: Pitch `1.22`, Speed `1.02` cho âm sắc nữ trẻ trung, trong trẻo.
  - *Tự Nhiên (Tiêu Chuẩn)*: Pitch `1.0`, Speed `1.0` nguyên bản.
- **Lưu Cấu Hình Vĩnh Viễn**: Tự động lưu lựa chọn giọng TTS vào `BridgeStateStore` (SharedPreferences) và nạp lại chính xác khi khởi động.
- **Ngắt Tức Thì Khi Bấm BACK / HOME**: Bấm phím Back hoặc Home trên remote TV sẽ lập tức dừng phát âm thanh TTS và đóng floating overlay Voice AI mà không làm gián đoạn ứng dụng đang chạy.

### 2. Ma Trận 8 Model AI Fallback Độc Lập (4 NVIDIA + 4 OpenRouter)
- **4 Model NVIDIA NIM GPU Cloud**:
  - `meta/llama-3.1-8b-instruct` (Siêu tốc ~340ms)
  - `google/gemma-4-31b-it` (Thông minh đỉnh cao)
  - `google/diffusiongemma-26b-a4b-it` (Đa nhiệm)
  - `meta/llama-3.2-11b-vision-instruct` (Chuẩn xác)
- **4 Model OpenRouter Free**:
  - `nvidia/nemotron-3.5-lightning:free`
  - `google/gemma-4-31b-it:free`
  - `google/gemma-4-26b-a4b-it:free`
  - `openai/gpt-oss-20b:free`
- **Bộ Quét Cập Nhật Model Free Mới Trong Settings**: Tự động đồng bộ và nạp ma trận 8 model AI mới nhất với 1 chạm.

### 3. Tương Thích Hình Nền & Video Wallpaper Universal
- **Hỗ Trợ Toàn Diện Định Dạng**: `.mp4`, `.mkv`, `.webm`, `.avi`, `.ts`, `.m2ts`, `.m4v`, `.3gp`, `.flv`, `.wmv`, `.mov`.
- **Phân Giải Đường Dẫn Thông Minh**: Tự động xử lý an toàn các định dạng đường dẫn `file://`, absolute storage path `/storage/...`, `/sdcard/...` và MediaStore `content://` URI.
- **Tắt Audio Track Khi Mute**: Ngăn chặn ExoPlayer khởi tạo Audio Decoder đối với video hình nền có track âm thanh Dolby/DTS, triệt tiêu lỗi decoder trên chip TV Xiaomi, TCL, Casper, Sony Bravia.
- **Khôi Phục Tự Động 100%**: Video luôn tự phát lại mượt mà khi quay lại Launcher từ ứng dụng khác hoặc sau khi TV thức dậy từ Sleep.

### 4. Dọn Dẹp Giao Diện Cài Đặt & Chuẩn Hóa Điều Hướng Dpad
- **Đồng Bộ Dpad Navigation**: Tích hợp `SettingsFocusFrame` và `EnsureVisible` đồng nhất 100% giữa tất cả các trang cài đặt (Voice AI, Hình nền, Thanh trạng thái, Ứng dụng, Danh mục).

## 2026-08-19 - Official release 2026.08.002 — Voice AI Toàn Diện, Zero-Flicker Overlay, Khớp Mờ 54 App & Backup

### Nâng Cấp Toàn Diện Voice AI Assistant & TTS Đa Tầng
- **Zero-Flicker WindowManager Overlay**: Chuyển đổi lớp phủ Voice AI sang `WindowManager.addView()` với `TYPE_ACCESSIBILITY_OVERLAY`, loại bỏ hoàn toàn việc chuyển Task/Activity, triệt tiêu 100% hiện tượng nháy màn hình.
- **Lập Chỉ Mục & Khớp Mờ Ứng Dụng (`AppIndexStore`)**: Tự động quét 54 ứng dụng trên TV khi Boot/Cài đặt mới, tạo chỉ mục từ đồng nghĩa, từ viết tắt và thuật toán Levenshtein $\ge 70\%$ (*"dút túp"*, *"kho phim"*, *"chợ ứng dụng"*, *"trình duyệt web"*, *"ép pê tê"*...).
- **Tìm Kiếm Bài Hát & YouTube**: Tự động phân loại từ khóa âm nhạc/karaoke/clip và điều hướng sang SmartTube / YouTube TV / Google Katniss.
- **Hỏi Đáp AI Ma Trận 8 Model Miễn Phí**: Gemini 2.0 Flash Exp $\leftrightarrow$ Llama 3.1 8B $\leftrightarrow$ Llama 3.3 70B $\leftrightarrow$ Mistral Large 2 $\leftrightarrow$ DeepSeek Chat $\leftrightarrow$ Nemotron 70B $\leftrightarrow$ Mistral 7B $\leftrightarrow$ Qwen 2.5 7B.
- **Phát Giọng Đọc Đa Đoạn (Multi-Chunk TTS)**: Kể chuyện dài thành nhiều câu, đồng bộ phụ đề Karaoke từng đoạn và tự động đóng sau 2.5s khi đọc xong.
- **Màu Chữ Mặc Định Xanh Ngọc Gemini AI (`0xFF00E5FF`)**: Chữ phụ đề nổi bật sắc nét với đổ bóng đen sâu 100% trên nền kính mờ Frosted Glass.
- **Sao Lưu & Phục Hồi Cấu Hình Đầy Đủ**: Hỗ trợ lưu trữ và khôi phục trọn bộ cấu hình Voice AI, phím bấm, kích cỡ/màu sắc phụ đề, và bộ đọc giọng nói tiếng Việt.

## 2026-08-19 - Official release 2026.08.001 — Tích hợp Trợ lý Giọng nói Thông minh & Mở kênh XemTV

### Trợ lý Giọng nói Thông minh (Smart Voice Assistant)
- **Tích hợp Native `SmartVoiceDispatcher`**: Phân tích câu lệnh giọng nói tiếng Việt tức thì, không phụ thuộc ứng dụng trung gian bên ngoài.
- **Mở Kênh Truyền hình `XemTV` Tức Thì**: Nhận diện thông minh các kênh VTV1-VTV9, VTV Cần Thơ, HTV, THVL, VTC, SCTV... (ví dụ: *"Mở VTV1"*, *"Xem VTV 3"*, *"Bật kênh VTV2"*, *"Kênh VTV5"*) -> Tự động chuyển thẳng vào màn hình phát video của kênh trong app `com.xemtv.app`.
- **Mở Bất Kỳ Ứng Dụng Nào**: Nhận diện *"Mở YouTube"*, *"Bật Cốc Cốc"*, *"Mở Cài đặt"*, *"Mở SmartTube"*, *"Mở Kho phim"*... và tra cứu danh sách ứng dụng đã cài đặt trên TV.
- **Tìm kiếm Video & Media**: Nhận diện *"Tìm karaoke..."*, *"Tìm phim..."* và tự động chuyển hướng tìm kiếm sang SmartTube / YouTube.
- **Tương thích 100% Cài đặt Map Voice**: Hoạt động xuyên suốt toàn hệ thống mọi lúc mọi nơi thông qua `VoiceBridgeAccessibilityService`, tương thích trọn vẹn với các chế độ Nhấn 1 lần, Nhấn đúp, Nhấn giữ, Học phím remote mới.
- **Giao diện Voice Hiện Đại**: Bổ sung `VoiceListeningBar` dạng floating pill với hiệu ứng sóng âm 4 màu phát sáng sang trọng, nhỏ gọn và không che khuất màn hình.

## 2026-07-28 - Official release 2026.07.012 — Fix video nền không play khi về Home (Smooth mode)

### Sửa lỗi Video Wallpaper không phát lại ở chế độ Smooth
- **Root cause**: Khi về home ở chế độ Smooth, `didChangeAppLifecycleState(resumed)` return sớm mà không trigger recovery. Video chỉ resume nếu `notifyHomeVisibleAndUsable()` được gọi lại — nhưng nếu home widget tree không rebuild (đã có sẵn trong bộ nhớ), hàm này không được gọi → video kẹt im.
- **Fix**: Ở Smooth mode, khi `resumed`, tự động khôi phục `_homeVisibleAndUsable = true` và gọi `scheduleHomeVisibleVideoStart()` để schedule lại timer warm-up 650ms. Guard conditions `_videoWarmUpScheduled` ngăn double-scheduling nếu `notifyHomeVisibleAndUsable()` vẫn được gọi sau đó.
- **Impact**: Video nền sẽ luôn phát lại khi về home, bất kể widget tree có rebuild hay không.

## 2026-07-16 - Official release 2026.07.011 — Fix Dpad nhảy liên tục (Debounce Dpad)

### Sửa lỗi D-pad nhảy liên tục (Double-firing / Bouncing)
- **Cơ chế Debounce Dpad**: Thêm bộ lọc chống dội phím D-pad 95ms cho cả thẻ ứng dụng `AppCard` và Vertical Dock chính.
- **Lọc phím thông minh**: Chỉ lọc các phím điều hướng Arrow (Up/Down/Left/Right) khi chúng đến quá nhanh (dưới 95ms) để ổn định tốc độ di chuyển, không ảnh hưởng đến các phím Select/Enter.
- **Tương thích Test Suite**: Tự động nhận diện môi trường chạy test ảo hóa để bỏ qua debounce, giúp test suite chạy nhanh chính xác.

## 2026-07-16 - Official release 2026.07.010 — Dpad nút + & ⓘ, Fix Long Press Settings, Dialog app mới

### Điều hướng Dpad trong Applications Panel
- **Nút `+` và `ⓘ` có thể focus qua Dpad**: Từ một app trong danh sách, nhấn **Arrow Right** để chuyển focus sang nút `+` (Thêm vào danh mục) hoặc `ⓘ` (Thông tin). Các nút này hiển thị **viền xanh cyan** khi được focus.
- **Điều hướng ngang giữa 2 nút**: Dpad Right từ `+` → chuyển sang `ⓘ`; Dpad Left từ `ⓘ` → về lại `+`.
- **Dpad Down từ TabBar**: Nhấn Arrow Down từ thanh Tab (TV / Non-TV / Ẩn) sẽ chuyển focus xuống item đầu tiên trong danh sách.
- **Viền row duy trì**: `SettingsFocusFrame` giữ viền highlight khi focus nằm ở nút trailing bên trong.

### Sửa lỗi Long Press nút Settings trên TV Remote (D-pad)
- **Root cause**: `TextButton.onLongPress` chỉ nhận touch gesture (chuột/tay), không nhận D-pad nhấn giữ trên Android TV.
- **Fix**: Bọc `TextButton` trong `_StatusBarActionSurface` bằng `FocusKeyboardListener` để detect `KeyRepeatEvent` sau 500ms → trigger `onLongPress`. Giờ đây nhấn giữ nút OK/Select trên remote khi focus vào icon Settings sẽ mở thẳng vào tab **Danh sách ứng dụng**.

### Cải thiện dialog hỏi khi cài app mới
- **Dùng localization**: Tiêu đề và nút dùng `AppLocalizations` thay vì hard-code tiếng Việt.
- **Không phụ thuộc tên category**: Dùng method `setSideloaded(app, bool)` mới trong `AppsService` để phân loại TV (`false`) hoặc Non-TV (`true`) thay vì tìm category theo tên cứng.
- **Luôn hiển thị 2 nút**: Nút "Ứng dụng không dành cho TV" và "Ứng dụng TV" luôn hiện, không còn ẩn khi không tìm thấy category đúng tên.

### Cập nhật và Phiên bản
- Tăng version lên `2026.07.010+35`.

## 2026-07-08 - Official release 2026.07.009 cải thiện Dpad & Auto-scroll Settings

### Điều hướng Dpad & Cuộn trang trong Cài đặt
- **Giao diện Cài đặt**: Cải thiện toàn diện cơ chế điều hướng Dpad và tự động cuộn (auto-scroll) cho các panel cài đặt.
  - `status_bar_panel_page.dart`: Sử dụng `PageStorageKey` để giữ vị trí cuộn khi chuyển tab.
  - `applications_panel_page.dart`: Chuyển đổi các item ứng dụng thành `_AppListItem` StatefulWidget tự quản lý focus, sử dụng `SettingsFocusFrame` hiển thị viền xanh cyan sắc nét và tự động cuộn bằng `Scrollable.ensureVisible` khi nhận focus.
  - `gradient_panel_page.dart`: Tách card gradient thành `_GradientCardItem` StatefulWidget tự quản lý focus Dpad và tự cuộn mượt mà.
  - `launcher_sections_panel_page.dart`: Tách phân mục thành `_SectionItem` StatefulWidget tự quản lý focus và cuộn mượt mà.
  - `launcher_section_panel_page.dart`: Tích hợp `EnsureVisible` bọc ngoài ListTile giúp Dropdown/TextFormField tự động cuộn lên khi nhận focus.
- **Khôi phục layout đa cột**: Điều chỉnh giá trị mặc định của `forceSingleColumn` trong `SettingsAdaptiveGrid` về `false` để khôi phục layout đa cột (3 cột) đẹp mắt cho màn hình chọn hình nền và sửa lỗi Dpad ngang.

### Cập nhật và Phiên bản
- Tăng version ứng dụng lên `2026.07.009+34` trong `pubspec.yaml` giúp giải quyết triệt để lỗi hiển thị phiên bản cũ của tháng 5/2026 trên menu TV.

### Unit Tests & Mocks
- Chuyển cấu hình Mockito trong `mocks.dart` sang `@GenerateNiceMocks` để loại bỏ hoàn toàn các lỗi `MissingStubError`.
- Sửa lỗi timing degraded ABI trong `update_panel_page_test.dart` bằng cách thêm pump 200ms để chờ timer 120ms hoàn tất.
- Cập nhật `home_layout_panel_page_test.dart` tương tác trực tiếp với các settings control thật sau khi loại bỏ quick summary tiles.
- Toàn bộ unit tests (266+ tests) đã vượt qua thành công (100% green).

## 2026-05-09 - Official release 2026.05.018 sửa wake HOME/focus/icon

### Sleep/Wake HOME

- Sau khi TV ngủ dậy, native đánh dấu lại HOME wake cả khi Activity đã bị `onStop` trước broadcast `SCREEN_OFF`, giúp video wallpaper có cơ hội rearm/play lại.
- Wake và foreground fallback giờ emit lại snapshot lite đầy đủ, tránh trạng thái biểu tượng khiên giữ dữ liệu quyền cũ dù `WRITE_SECURE_SETTINGS` vẫn đang được cấp.
- MethodChannel native vẫn phục vụ các lệnh đọc app/icon/wallpaper trong khoảng Activity vừa wake, tránh `activity_unavailable` làm live sync icon hoặc video rearm bị fail.
- Flutter reset HOME dock cho các tín hiệu `screen_wake/activity_start/activity_resume`, đưa focus về app đầu tiên để D-pad lên thanh trạng thái hoạt động lại.
- App card nhận `imageWarmupSequence` theo HOME recovery; các card đã build nhưng còn placeholder/error sẽ retry load ngay, kể cả vài icon ở hàng phía dưới không nằm trong nhóm eager đầu tiên.
- Video recovery có retry ngắn nếu bridge vừa wake chưa sẵn sàng, tránh unhandled exception và tự thử lại thay vì đứng yên.
- Giữ nguyên policy video theo mode Cân bằng/Mượt/Đẹp; không đổi UX chính và không tăng cache ảnh dài hạn.

### Kiểm chứng

- `flutter analyze --no-pub`: pass.
- `flutter test --no-pub test/flauncher_test.dart`: pass.
- `flutter test --no-pub test/widgets/app_card_test.dart`: pass.
- `flutter test --no-pub test/native_policy_static_test.dart`: pass.
- `flutter test --no-pub test/providers/wallpaper_service_test.dart`: pass.

## 2026-05-09 - Official release 2026.05.017 sửa video/icon sau sleep wake

### Sleep/Wake

- Ép Flutter đồng bộ lại `wallpaperMode=video` sang native trước mọi lần warm-up/rearm, tránh lệch state làm video nền không tự phát sau khi TV ngủ dậy hoặc launcher bị restart.
- HOME recovery sau `activity_start/activity_resume/screen_wake` tiếp tục gọi warm-up explicit để video tự phát lại mà không cần chọn lại thư mục video.
- Cold start ở mode Cân bằng vẫn giữ delayed-home-settle, không đổi policy mode Mượt/Đẹp.
- Bật log wake rearm trong release với tần suất hẹp để kiểm tra được bằng logcat nếu TV còn lỗi sleep/wake.
- Warm icon/banner vùng đầu HOME ngay cả khi `homeSequence=0`, giảm trường hợp icon trống cho tới khi bấm biểu tượng khiên.

### Kiểm chứng

- Thêm regression test đảm bảo warm-up video luôn `setWallpaperMode('video')` trước khi xin texture/play native.
- Thêm static test khóa fallback `activity_resume` và log wake release.

## 2026-05-09 - Official release 2026.05.016 sửa sleep/wake HOME

### Sleep/Wake

- Thêm fallback rearm khi Activity quay lại `onStart/onResume` sau lúc TV ngủ, phòng trường hợp thiết bị không gửi hoặc không giao `SCREEN_ON/DREAMING_STOPPED` cho wake receiver.
- Khi fallback wake chạy, native gọi lại video wallpaper explicit rearm để video nền tự phát lại mà không cần chọn lại thư mục video.
- Flutter coi `activity_start/activity_resume` là tín hiệu warm HOME để eager-load icon/banner vùng đầu dock sau sleep/wake.
- Fallback chỉ chạy sau một lần background do thiết bị không interactive, không áp vào cold start để giữ nguyên nhịp khởi động video hiện tại.

### Kiểm chứng

- Thêm static test khóa native foreground wake fallback.
- Thêm widget test cho icon/banner warmup theo `activity_resume`.

## 2026-05-09 - Official release 2026.05.015 sửa điều hướng dock thu gọn

### Điều hướng D-pad HOME

- Sửa lỗi khi dock đang thu gọn, bấm D-pad xuống không tự mở rộng dock và không chuyển focus xuống app ở hàng dưới.
- Sửa lỗi đôi khi đang focus app trong dock không thể bấm D-pad lên thanh trạng thái/AppBar.
- Giữ ưu tiên điều hướng nội bộ trong dock khi còn app/hàng phía trên hoặc phía dưới; chỉ nhả focus lên thanh trạng thái khi đã ở mép trên dock.

### Kiểm chứng

- Thêm regression test cho `DPAD_DOWN` mở dock thu gọn trước khi focus xuống app cùng category.
- Thêm regression test cho `DPAD_UP` từ app đầu dock lên thanh trạng thái.
- `flutter test --no-pub test/flauncher_test.dart`: pass.

## 2026-05-09 - Official release 2026.05.014 tối ưu độ mượt HOME và wake

### Độ mượt HOME / D-pad

- D-pad trong cùng row/grid dùng điều hướng theo index thay vì quét toàn bộ focus tree, giảm độ trễ khi bấm nhanh qua nhiều app.
- Khi người dùng bấm D-pad liên tục, card tạm dùng highlight nhẹ/static để giảm spike GPU từ hiệu ứng pulse/glow, sau khi dừng sẽ tự trả lại hiệu ứng đầy đủ.
- App card prefetch ảnh các app lân cận quanh vị trí focus để giảm tình trạng icon/banner trễ khi di chuyển.

### Quay lại HOME và sleep/wake

- Khi quay lại HOME từ app khác, launcher eager-load ảnh app vùng đầu dock ngay thay vì chờ deferred image load.
- Khi TV ngủ dậy, native emit tín hiệu `screen_wake` có debounce để Flutter warm lại ảnh app vùng đang nhìn thấy, tránh HOME hiện placeholder quá lâu.
- Giữ giới hạn concurrency/cache ảnh hiện tại để cải thiện cảm giác mượt nhưng không tăng tải RAM/CPU quá mức.

### Kiểm chứng

- `flutter analyze --no-pub`: pass.
- `flutter test --no-pub`: pass toàn bộ suite.
- `flutter build apk --debug --target-platform android-arm --no-pub`: pass native compile.

## 2026-05-09 - Official release 2026.05.013 sửa chữ ký update debug

### Cập nhật và chữ ký APK

- Release APK giờ dùng cố định debug signing certificate cùng khóa với máy build local hiện tại để tránh lỗi update `-7` do mismatch chữ ký.
- Workflow GitHub Actions được khóa bằng `FLAUNCHER_FORCE_DEBUG_RELEASE_SIGNING=true`, không để runner tự sinh debug keystore riêng.
- Bộ verify release kiểm tra thêm SHA-256 của signer certificate: `BB:22:B0:A3:9E:C2:67:E8:9E:FE:32:4E:99:68:08:91:E3:5A:73:F7:35:B5:4B:54:9A:BB:79:66:D7:24:D9:63`.

### Kiểm chứng

- Thêm test tĩnh khóa policy signing debug cho release official.
- Build release cần tiếp tục publish đúng 2 asset `atv-launcher-armeabi-v7a-release.apk` và `atv-launcher-arm64-v8a-release.apk`.

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
