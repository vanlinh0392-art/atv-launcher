import 'package:flauncher/providers/search_service.dart';
import 'package:flauncher/providers/system_bridge_service.dart';
import 'package:flauncher/widgets/rounded_switch_list_tile.dart';
import 'package:flauncher/widgets/settings/settings_chrome.dart';
import 'package:flauncher/widgets/settings/settings_localized_values.dart';
import 'package:flauncher/widgets/settings/tv_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class VoiceSearchPanelPage extends StatefulWidget {
  static const String routeName = "voice_search_panel";
  static const String _summaryDebugLabel = 'voice_search_summary_metrics';
  final FocusNode? primaryFocusNode;

  const VoiceSearchPanelPage({
    super.key,
    this.primaryFocusNode,
  });

  @override
  State<VoiceSearchPanelPage> createState() => _VoiceSearchPanelPageState();
}

class _VoiceSearchPanelPageState extends State<VoiceSearchPanelPage> {
  int _subtitleSize = 20;
  int _subtitleColor = 0xFF00E5FF;
  String _ttsEngine = 'auto';

  @override
  void initState() {
    super.initState();
    _loadVoiceConfig();
  }

  Future<void> _loadVoiceConfig() async {
    try {
      final bridge = context.read<SystemBridgeService>();
      final config = await bridge.getVoiceSubtitleConfig();
      final tts = await bridge.getTtsEngine();
      if (!mounted) return;
      setState(() {
        _subtitleSize = (config['size'] as num?)?.toInt() ?? 20;
        _subtitleColor = (config['color'] as num?)?.toInt() ?? 0xFF00E5FF;
        _ttsEngine = tts['engine']?.toString() ?? 'auto';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _subtitleSize = 20;
        _subtitleColor = 0xFF00E5FF;
        _ttsEngine = 'auto';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    Widget actionCard({
      required String title,
      String? subtitle,
      required IconData icon,
      required Future<void> Function()? onPressed,
    }) =>
        SettingsActionCard(
          title: title,
          subtitle: subtitle,
          icon: icon,
          onPressed: onPressed,
          focusEmphasis: 1.32,
        );

    Widget sectionHeader(String title, IconData icon) => Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8, top: 6),
          child: Row(
            children: [
              Icon(icon, size: 20, color: const Color(0xFF38BDF8)),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: const Color(0xFF38BDF8),
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
              ),
            ],
          ),
        );

    return Consumer2<SystemBridgeService, SearchService>(
      builder: (context, bridgeService, searchService, _) {
        final status = bridgeService.voiceStatus;
        final mode = (status['mode'] as num?)?.toInt() ?? 2;
        final keyCode = status['keyCode']?.toString() ?? '0';
        final interceptEnabled = status['interceptEnabled'] == true;

        return ListView(
          key: const PageStorageKey<String>(VoiceSearchPanelPage.routeName),
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            // ==========================================
            // HEADER: TỔNG QUAN & SỨC KHỎE VOICE AI
            // ==========================================
            SettingsSummarySection(
              debugLabel: VoiceSearchPanelPage._summaryDebugLabel,
              child: SettingsMetricsGrid(
                minChildWidth: 160,
                maxColumns: 3,
                children: [
                  SettingsMetricTile(
                    label: 'Chế độ kích hoạt',
                    value: localizedVoiceMode(localizations, mode),
                    icon: Icons.mic_none_outlined,
                  ),
                  SettingsMetricTile(
                    label: 'Mã phím Remote',
                    value: keyCode,
                    icon: Icons.keyboard_outlined,
                  ),
                  SettingsMetricTile(
                    label: 'Cầu nối Trợ năng',
                    value: localizedBridgeHealth(
                      localizations,
                      status['health']?.toString() ?? '',
                    ),
                    icon: Icons.health_and_safety_outlined,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ==========================================
            // SECTION 1: KÍCH HOẠT & PHÍM REMOTE TV
            // ==========================================
            sectionHeader('KÍCH HOẠT & PHÍM REMOTE TV', Icons.touch_app_outlined),
            SettingsSurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SettingsChoiceCard<int>(
                    focusNode: widget.primaryFocusNode,
                    onMoveUpAtBoundary: () =>
                        focusCurrentSettingsNodeByDebugLabel(
                      VoiceSearchPanelPage._summaryDebugLabel,
                    ),
                    selectorKey: const Key('voice_search_mode_selector'),
                    optionKeyPrefix: 'voice_search_mode_option',
                    title: 'Cách thức bấm phím Voice',
                    subtitle: 'Lựa chọn thao tác bấm trên remote để kích hoạt Trợ lý Voice AI',
                    icon: Icons.tune,
                    value: mode,
                    options: <SettingsChoiceOption<int>>[
                      SettingsChoiceOption<int>(
                        value: 2,
                        label: 'Nhấn giữ phím (Khuyên dùng)',
                      ),
                      SettingsChoiceOption<int>(
                        value: 0,
                        label: 'Nhấn đúp (2 lần liên tiếp)',
                      ),
                      SettingsChoiceOption<int>(
                        value: 1,
                        label: 'Nhấn 1 lần (Một chạm)',
                      ),
                      SettingsChoiceOption<int>(
                        value: 3,
                        label: 'Nhấn đúp & giữ',
                      ),
                    ],
                    valueLabelBuilder: (value) =>
                        localizedVoiceMode(localizations, value),
                    onChanged: (value) async {
                      await bridgeService.setVoiceMode(mode: value);
                    },
                  ),
                  const SizedBox(height: 12),
                  SettingsChoiceCard<int>(
                    selectorKey: const Key('voice_search_key_selector'),
                    optionKeyPrefix: 'voice_search_key_option',
                    title: 'Phím gán gọi Trợ lý AI (Tách biệt Katniss)',
                    subtitle: 'Chọn phím vật lý độc lập trên remote để không bị xung đột với Google Assistant',
                    icon: Icons.keyboard_outlined,
                    value: (status['keyCode'] as num?)?.toInt() ?? 0,
                    options: const <SettingsChoiceOption<int>>[
                      SettingsChoiceOption<int>(
                        value: 0,
                        label: 'Tự động đa năng (Nhận diện mọi hãng TV [231, 84, 219, 259, 170...])',
                      ),
                      SettingsChoiceOption<int>(
                        value: 231,
                        label: 'Google TV / Chromecast / Xiaomi (Phím Mic 231)',
                      ),
                      SettingsChoiceOption<int>(
                        value: 84,
                        label: 'Sony Bravia / Casper / TCL (Phím Search 84)',
                      ),
                      SettingsChoiceOption<int>(
                        value: 219,
                        label: 'Android Box AOSP / Tanix / Mecool (Phím Assist 219)',
                      ),
                      SettingsChoiceOption<int>(
                        value: 3,
                        label: 'Phím Home (Nhấn giữ - Chuẩn 100% mọi TV)',
                      ),
                      SettingsChoiceOption<int>(
                        value: 23,
                        label: 'Phím OK / D-pad Center (Nhấn giữ)',
                      ),
                      SettingsChoiceOption<int>(
                        value: 82,
                        label: 'Phím Menu / Cài đặt (Menu Key 82)',
                      ),
                      SettingsChoiceOption<int>(
                        value: 170,
                        label: 'Phím Live TV / Kênh (TV Key 170)',
                      ),
                      SettingsChoiceOption<int>(
                        value: 183,
                        label: 'Phím Màu Đỏ (Color Key Red 183)',
                      ),
                      SettingsChoiceOption<int>(
                        value: 184,
                        label: 'Phím Màu Xanh Lá (Color Key Green 184)',
                      ),
                      SettingsChoiceOption<int>(
                        value: 185,
                        label: 'Phím Màu Vàng (Color Key Yellow 185)',
                      ),
                      SettingsChoiceOption<int>(
                        value: 186,
                        label: 'Phím Màu Xanh Dương (Color Key Blue 186)',
                      ),
                      SettingsChoiceOption<int>(
                        value: 259,
                        label: 'Phím Help / Hỗ trợ Sony (Key 259)',
                      ),
                      SettingsChoiceOption<int>(
                        value: 188,
                        label: 'Phím Bookmark / Custom 1 (Key 188)',
                      ),
                    ],
                    valueLabelBuilder: (value) {
                      switch (value) {
                        case 231:
                          return 'Google TV / Xiaomi (Phím 231)';
                        case 84:
                          return 'Sony / Casper / TCL (Phím 84)';
                        case 219:
                          return 'Android Box AOSP (Phím 219)';
                        case 3:
                          return 'Phím Home (Nhấn giữ)';
                        case 82:
                          return 'Phím Menu (82)';
                        case 23:
                          return 'Phím OK (Nhấn giữ)';
                        case 170:
                          return 'Phím TV / Live (170)';
                        case 183:
                          return 'Phím Màu Đỏ (183)';
                        case 184:
                          return 'Phím Màu Xanh Lá (184)';
                        case 185:
                          return 'Phím Màu Vàng (185)';
                        case 186:
                          return 'Phím Màu Xanh Dương (186)';
                        case 259:
                          return 'Phím Help Sony (259)';
                        case 188:
                          return 'Phím Bookmark (188)';
                        default:
                          return 'Tự động đa năng (Mọi TV)';
                      }
                    },
                    onChanged: (value) async {
                      await bridgeService.setVoiceMode(keyCode: value);
                    },
                  ),
                  const SizedBox(height: 12),
                  RoundedSwitchListTile(
                    value: interceptEnabled,
                    onChanged: bridgeService.setVoiceInterceptEnabled,
                    title: Text(
                      'Bắt phím giọng nói toàn hệ thống (Cả ngoài Home và trong App)',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    secondary: const Icon(Icons.hearing_outlined),
                  ),
                  const SizedBox(height: 12),
                  SettingsAdaptiveGrid(
                    spacing: 12,
                    runSpacing: 12,
                    minChildWidth: 240,
                    maxColumns: 2,
                    children: [
                      actionCard(
                        title: 'Học phím Remote mới',
                        subtitle: 'Bấm nút này rồi bấm phím bất kỳ trên Remote TV để gán Voice',
                        icon: Icons.sensors_outlined,
                        onPressed: () async {
                          await bridgeService.startKeyLearning();
                          if (!context.mounted) return;
                          showDialog<void>(
                            context: context,
                            barrierDismissible: false,
                            builder: (dialogCtx) => AlertDialog(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: const BorderSide(color: Color(0xFF38BDF8), width: 1.5),
                              ),
                              backgroundColor: const Color(0xFF141721),
                              title: const Row(
                                children: [
                                  Icon(Icons.sensors, color: Color(0xFF38BDF8), size: 28),
                                  SizedBox(width: 12),
                                  Text(
                                    'Đang Lắng Nghe Remote TV',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Hãy hướng Remote về phía TV và BẤM 1 PHÍM BẤT KỲ bạn muốn dùng để gọi Trợ lý Voice AI (Nút Mic, Nút Sao ★, Nút Màu, Nút Số...).',
                                    style: TextStyle(color: Color(0xFFE2E8F0), fontSize: 14, height: 1.4),
                                  ),
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0x3338BDF8),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.check_circle_outline, color: Color(0xFF38BDF8), size: 20),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Khi bạn bấm phím, hệ thống sẽ tự động ghi nhớ và đọc xác nhận.',
                                            style: TextStyle(color: Color(0xFF38BDF8), fontSize: 13),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(dialogCtx);
                                  },
                                  child: const Text('Đóng / Hoàn tất', style: TextStyle(color: Colors.white70)),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      actionCard(
                        title: 'Khôi phục phím Xiaomi / Mặc định',
                        subtitle: 'Gán lại các mã phím gốc của Android TV Box',
                        icon: Icons.restart_alt,
                        onPressed: () async {
                          await bridgeService.resetVoiceMapping();
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Đã khôi phục cấu hình phím mặc định!')),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ==========================================
            // SECTION 2: TRÍ TUỆ NHÂN TẠO AI & GIỌNG ĐỌC TTS
            // ==========================================
            sectionHeader('TRÍ TUỆ NHÂN TẠO AI & GIỌNG ĐỌC TTS', Icons.auto_awesome),
            SettingsSurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SettingsChoiceCard<String>(
                    selectorKey: const Key('voice_tts_engine_selector'),
                    optionKeyPrefix: 'voice_tts_engine_option',
                    title: 'Chọn giọng đọc Tiếng Việt',
                    subtitle: 'Chất giọng phản hồi khi AI trả lời hoặc mở kênh TV',
                    icon: Icons.spatial_audio_off_outlined,
                    value: _ttsEngine,
                    options: const <SettingsChoiceOption<String>>[
                      SettingsChoiceOption<String>(value: 'auto', label: 'Tự động (Google Neural TTS)'),
                      SettingsChoiceOption<String>(value: 'edge_hoaimy', label: 'Nữ Hoài My (Ngọt ngào, tự nhiên)'),
                      SettingsChoiceOption<String>(value: 'edge_namminh', label: 'Nam Minh (Trầm ấm, rõ ràng)'),
                    ],
                    valueLabelBuilder: (value) {
                      switch (value) {
                        case 'edge_namminh':
                          return 'Nam Minh';
                        case 'edge_hoaimy':
                          return 'Nữ Hoài My';
                        default:
                          return 'Tự động (Google Neural)';
                      }
                    },
                    onChanged: (value) async {
                      setState(() => _ttsEngine = value);
                      await bridgeService.setTtsEngine(value);
                    },
                  ),
                  const SizedBox(height: 12),
                  SettingsAdaptiveGrid(
                    spacing: 12,
                    runSpacing: 12,
                    minChildWidth: 240,
                    maxColumns: 2,
                    children: [
                      actionCard(
                        title: 'Cập nhật Model AI Free mới nhất',
                        subtitle: 'Quét và kích hoạt Top Model AI miễn phí',
                        icon: Icons.refresh_outlined,
                        onPressed: () async {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Đang quét máy chủ AI...')),
                          );
                          final res = await bridgeService.updateDynamicFreeAiModels();
                          if (!context.mounted) return;
                          final message = res['message']?.toString() ??
                              (res['success'] == true
                                  ? 'Đã cập nhật danh sách Model AI Free thành công!'
                                  : 'Không thể kết nối đến máy chủ AI');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(message), duration: const Duration(seconds: 4)),
                          );
                        },
                      ),
                      actionCard(
                        title: 'Thử nghiệm tìm kiếm & Thu âm Mic',
                        subtitle: 'Kiểm tra độ nhạy của micro',
                        icon: Icons.mic_none_outlined,
                        onPressed: () async {
                          final result = await searchService.startSpeechRecognizer();
                          if (!context.mounted) return;
                          final text = result['text']?.toString() ?? '';
                          final message = text.trim().isNotEmpty
                              ? localizations.speechCapturedMessage(text)
                              : (result['message']?.toString() ?? localizations.speechCaptureNoTextMessage);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(message)),
                          );
                        },
                      ),
                      actionCard(
                        title: 'Thử phát giọng đọc TV',
                        subtitle: 'Phát thử giọng nói qua loa TV',
                        icon: Icons.volume_up_outlined,
                        onPressed: () async {
                          await bridgeService.testTtsVoice('Xin chào! Trợ lý FLauncher TV đã sẵn sàng phục vụ bạn.');
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Đang phát giọng đọc mẫu qua loa TV...')),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ==========================================
            // SECTION 3: GIAO DIỆN & PHỤ ĐỀ AI
            // ==========================================
            sectionHeader('GIAO DIỆN & PHỤ ĐỀ AI TRÊN MÀN HÌNH', Icons.palette_outlined),
            SettingsSurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SettingsChoiceCard<int>(
                    selectorKey: const Key('voice_subtitle_size_selector'),
                    optionKeyPrefix: 'voice_subtitle_size_option',
                    title: 'Cỡ chữ phụ đề AI (Voice Subtitle Size)',
                    subtitle: 'Tùy chỉnh độ lớn chữ phản hồi của Trợ lý trên màn hình TV',
                    icon: Icons.format_size,
                    value: _subtitleSize,
                    options: const <SettingsChoiceOption<int>>[
                      SettingsChoiceOption<int>(value: 16, label: 'Nhỏ (16sp)'),
                      SettingsChoiceOption<int>(value: 20, label: 'Chuẩn (20sp)'),
                      SettingsChoiceOption<int>(value: 24, label: 'Vừa (24sp)'),
                      SettingsChoiceOption<int>(value: 28, label: 'Lớn (28sp)'),
                    ],
                    valueLabelBuilder: (value) => '${value}sp',
                    onChanged: (value) async {
                      setState(() => _subtitleSize = value);
                      await bridgeService.setVoiceSubtitleConfig(size: value);
                    },
                  ),
                  const SizedBox(height: 12),
                  SettingsChoiceCard<int>(
                    selectorKey: const Key('voice_subtitle_color_selector'),
                    optionKeyPrefix: 'voice_subtitle_color_option',
                    title: 'Màu sắc phụ đề AI (Subtitle Color)',
                    subtitle: 'Màu chữ hiển thị khi trợ lý trả lời trên màn hình TV',
                    icon: Icons.palette_outlined,
                    value: _subtitleColor,
                    options: const <SettingsChoiceOption<int>>[
                      SettingsChoiceOption<int>(value: 0xFF00E5FF, label: 'Xanh Cyan Gemini (Mặc định)'),
                      SettingsChoiceOption<int>(value: 0xFFFFFFFF, label: 'Trắng tinh khôi'),
                      SettingsChoiceOption<int>(value: 0xFF00E676, label: 'Xanh Lục Ngọc'),
                      SettingsChoiceOption<int>(value: 0xFFFFD700, label: 'Vàng Hổ Phách'),
                      SettingsChoiceOption<int>(value: 0xFFF472B6, label: 'Hồng Pastel'),
                    ],
                    valueLabelBuilder: (value) {
                      switch (value) {
                        case 0xFF00E5FF:
                          return 'Xanh Cyan Gemini';
                        case 0xFF00E676:
                          return 'Xanh Lục Ngọc';
                        case 0xFFFFD700:
                          return 'Vàng Hổ Phách';
                        case 0xFFF472B6:
                          return 'Hồng Pastel';
                        default:
                          return 'Trắng tinh khôi';
                      }
                    },
                    onChanged: (value) async {
                      setState(() => _subtitleColor = value);
                      await bridgeService.setVoiceSubtitleConfig(color: value);
                    },
                  ),
                  const SizedBox(height: 14),
                  // Live Preview Box
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(120),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      children: [
                        Row(
                          children: [
                            Container(width: 4, height: 16, decoration: BoxDecoration(color: const Color(0xFF38BDF8), borderRadius: BorderRadius.circular(4))),
                            const SizedBox(width: 3),
                            Container(width: 4, height: 24, decoration: BoxDecoration(color: const Color(0xFF818CF8), borderRadius: BorderRadius.circular(4))),
                            const SizedBox(width: 3),
                            Container(width: 4, height: 20, decoration: BoxDecoration(color: const Color(0xFFC084FC), borderRadius: BorderRadius.circular(4))),
                            const SizedBox(width: 3),
                            Container(width: 4, height: 12, decoration: BoxDecoration(color: const Color(0xFFF472B6), borderRadius: BorderRadius.circular(4))),
                          ],
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            'Xem trước: Hôm nay trời nắng ráo, nhiệt độ khoảng 28 độ C.',
                            style: TextStyle(
                              color: Color(_subtitleColor),
                              fontSize: _subtitleSize.toDouble(),
                              fontWeight: FontWeight.bold,
                              shadows: const [
                                Shadow(color: Colors.black, blurRadius: 8, offset: Offset(0, 2)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ==========================================
            // SECTION 4: CHẨN ĐOÁN & QUẢN TRỊ HỆ THỐNG
            // ==========================================
            sectionHeader('CHẨN ĐOÁN & QUẢN TRỊ HỆ THỐNG', Icons.build_circle_outlined),
            SettingsSurfaceCard(
              child: SettingsAdaptiveGrid(
                spacing: 12,
                runSpacing: 12,
                minChildWidth: 240,
                maxColumns: 3,
                children: [
                  actionCard(
                    title: 'Thử mở Voice AI Overlay',
                    subtitle: 'Kiểm tra giao diện sóng cực quang',
                    icon: Icons.play_circle_outline,
                    onPressed: () async => _showResult(
                      context,
                      await bridgeService.testVoiceSearch(),
                    ),
                  ),
                  actionCard(
                    title: localizations.repairAccessibility,
                    subtitle: 'Tự động sửa lỗi mất quyền Trợ năng',
                    icon: Icons.build_circle_outlined,
                    onPressed: () async => _showResult(
                      context,
                      await bridgeService.repairAccessibility(),
                    ),
                  ),
                  actionCard(
                    title: localizations.openAccessibilitySettings,
                    subtitle: 'Mở màn hình cài đặt của Android',
                    icon: Icons.settings_accessibility,
                    onPressed: () async {
                      bridgeService.openAccessibilitySettings();
                    },
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  void _showResult(BuildContext context, Map<String, dynamic> result) {
    if (!context.mounted) {
      return;
    }
    final message = result['message']?.toString() ??
        AppLocalizations.of(context)!.actionCompleted;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
