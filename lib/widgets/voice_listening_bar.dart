import 'dart:math' as math;
import 'package:flutter/material.dart';

enum VoiceListeningState {
  listening,
  processing,
  speaking,
  success,
  error,
}

class VoiceListeningBar extends StatefulWidget {
  final VoiceListeningState state;
  final String? recognizedText;
  final String? statusMessage;
  final String? spokenSubtitleText;
  final VoidCallback? onCancel;

  const VoiceListeningBar({
    super.key,
    this.state = VoiceListeningState.listening,
    this.recognizedText,
    this.statusMessage,
    this.spokenSubtitleText,
    this.onCancel,
  });

  @override
  State<VoiceListeningBar> createState() => _VoiceListeningBarState();
}

class _VoiceListeningBarState extends State<VoiceListeningBar>
    with TickerProviderStateMixin {
  late final AnimationController _animController;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isListening = widget.state == VoiceListeningState.listening;
    final isProcessing = widget.state == VoiceListeningState.processing;
    final isSpeaking = widget.state == VoiceListeningState.speaking;
    final isSuccess = widget.state == VoiceListeningState.success;

    String displayText;
    if (widget.spokenSubtitleText != null && widget.spokenSubtitleText!.isNotEmpty) {
      displayText = widget.spokenSubtitleText!;
    } else if (widget.statusMessage != null && widget.statusMessage!.isNotEmpty) {
      displayText = widget.statusMessage!;
    } else if (widget.recognizedText != null && widget.recognizedText!.isNotEmpty) {
      displayText = widget.recognizedText!;
    } else {
      displayText = switch (widget.state) {
        VoiceListeningState.listening => 'Đang lắng nghe...',
        VoiceListeningState.processing => 'Gemini đang suy nghĩ...',
        VoiceListeningState.speaking => 'Gemini đang trả lời...',
        VoiceListeningState.success => 'Đã hoàn tất',
        VoiceListeningState.error => 'Không nhận diện được giọng nói',
      };
    }

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 40, left: 32, right: 32),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 780),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          // 100% Trong suốt - Thiết kế chuẩn Gemini Web & Android
          decoration: const BoxDecoration(
            color: Colors.transparent,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Biểu tượng Gemini AI Star & 4 Dải Sóng Âm Cực Quang (Aurora Glow)
              if (isListening || isProcessing || isSpeaking)
                _buildGeminiWaveform()
              else if (isSuccess)
                _buildSuccessSparkle()
              else
                _buildErrorMic(),
              const SizedBox(width: 18),
              // 2. Phụ đề Typography phát sáng đa tầng chống chói, siêu nét trên TV
              Flexible(
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Text(
                      displayText,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.35,
                        height: 1.35,
                        shadows: [
                          // Đổ bóng đen sâu chống trùng màu nền
                          const Shadow(
                            color: Color(0xEE000000),
                            blurRadius: 16,
                            offset: Offset(0, 3),
                          ),
                          const Shadow(
                            color: Color(0xCC000000),
                            blurRadius: 28,
                            offset: Offset(0, 4),
                          ),
                          // Viền hào quang ánh xanh tím Gemini nhẹ
                          Shadow(
                            color: isSpeaking
                                ? const Color(0x99A855F7)
                                : const Color(0x8038BDF8),
                            blurRadius: 20,
                            offset: Offset.zero,
                          ),
                        ],
                      ),
                      maxLines: isSpeaking ? 3 : 1,
                      overflow: TextOverflow.ellipsis,
                    );
                  },
                ),
              ),
              if (widget.onCancel != null) ...[
                const SizedBox(width: 14),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 22),
                  onPressed: widget.onCancel,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 20,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGeminiWaveform() {
    // 4 Màu cực quang đặc trưng của Google Gemini AI
    final geminiColors = [
      const Color(0xFF38BDF8), // Gemini Sky Blue
      const Color(0xFF818CF8), // Gemini Indigo
      const Color(0xFFC084FC), // Gemini Purple
      const Color(0xFFF472B6), // Gemini Pink Sparkle
    ];

    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(4, (index) {
              final phase = (index * 0.25);
              final progress = (_animController.value + phase) % 1.0;
              final scale = 0.40 + 0.60 * math.sin(progress * math.pi * 2);
              final height = 12.0 + (24.0 * scale);

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 3.5),
                width: 7.0,
                height: height,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      geminiColors[index],
                      geminiColors[(index + 1) % geminiColors.length],
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: geminiColors[index].withOpacity(0.90),
                      blurRadius: 14,
                      spreadRadius: 2.5,
                      offset: Offset.zero,
                    ),
                    BoxShadow(
                      color: const Color(0xFF60A5FA).withOpacity(0.4),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
              );
            }),
          ),
        );
      },
    );
  }

  Widget _buildSuccessSparkle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Color(0x9900E676),
            blurRadius: 20,
            spreadRadius: 3,
          ),
        ],
      ),
      child: const Icon(
        Icons.check_circle_rounded,
        color: Color(0xFF00E676),
        size: 30,
      ),
    );
  }

  Widget _buildErrorMic() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Color(0x99FF5252),
            blurRadius: 20,
            spreadRadius: 3,
          ),
        ],
      ),
      child: const Icon(
        Icons.mic_off_rounded,
        color: Color(0xFFFF5252),
        size: 30,
      ),
    );
  }
}
