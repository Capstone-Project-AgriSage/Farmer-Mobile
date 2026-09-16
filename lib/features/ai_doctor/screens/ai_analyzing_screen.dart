import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

class AiAnalyzingScreen extends StatefulWidget {
  const AiAnalyzingScreen({super.key});
  @override
  State<AiAnalyzingScreen> createState() => _AiAnalyzingScreenState();
}

class _AiAnalyzingScreenState extends State<AiAnalyzingScreen> with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _progressController;
  int _currentStep = 0;

  static const _steps = [
    _AnalysisStep(Icons.cloud_upload_outlined, 'Đang tải ảnh lên...'),
    _AnalysisStep(Icons.crop_free, 'Nhận diện vùng bệnh...'),
    _AnalysisStep(Icons.biotech_outlined, 'Phân tích triệu chứng...'),
    _AnalysisStep(Icons.storage_outlined, 'Đối chiếu cơ sở dữ liệu...'),
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _runAnalysis();
  }

  Future<void> _runAnalysis() async {
    for (int i = 0; i < _steps.length; i++) {
      await Future.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      setState(() => _currentStep = i + 1);
    }
    // Finish → navigate to result
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    context.go('/ai-scan/result');
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _currentStep / _steps.length;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Đang phân tích'),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),

            // ── Animated AI Icon ──────────────────────────────────
            AnimatedBuilder(
              animation: _pulseController,
              builder: (_, child) {
                final scale = 1.0 + (_pulseController.value * 0.08);
                return Transform.scale(scale: scale, child: child);
              },
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6A1B9A), Color(0xFF9C27B0)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF9C27B0).withOpacity(0.3),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(Icons.auto_awesome, size: 52, color: Colors.white),
              ),
            ),
            const SizedBox(height: 32),

            Text('AI đang phân tích ảnh', style: AppTextStyles.h2, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Vui lòng chờ trong giây lát...',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: 32),

            // ── Progress Bar ──────────────────────────────────────
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: AppColors.surfaceSubtle,
                valueColor: const AlwaysStoppedAnimation(Color(0xFF6A1B9A)),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _currentStep < _steps.length ? _steps[_currentStep].label : 'Hoàn tất!',
                  style: AppTextStyles.caption.copyWith(color: const Color(0xFF6A1B9A), fontWeight: FontWeight.w600),
                ),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // ── Steps List ────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceSubtle,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: List.generate(_steps.length, (i) {
                  final isDone = i < _currentStep;
                  final isCurrent = i == _currentStep && _currentStep < _steps.length;
                  return Padding(
                    padding: EdgeInsets.only(bottom: i < _steps.length - 1 ? 12 : 0),
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: isDone
                                ? AppColors.statusSuccess
                                : isCurrent
                                    ? const Color(0xFF6A1B9A)
                                    : AppColors.surfaceDim,
                            shape: BoxShape.circle,
                          ),
                          child: isDone
                              ? const Icon(Icons.check, color: Colors.white, size: 16)
                              : isCurrent
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Icon(_steps[i].icon, color: AppColors.textMuted, size: 14),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _steps[i].label,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: isDone || isCurrent ? AppColors.textPrimary : AppColors.textMuted,
                              fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ),
                        if (isDone)
                          Text('✓', style: TextStyle(color: AppColors.statusSuccess, fontSize: 14, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  );
                }),
              ),
            ),

            const Spacer(),

            // ── AI Safety Notice ──────────────────────────────────
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(10),
                border: const Border.fromBorderSide(BorderSide(color: Color(0xFFFFE082))),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield_outlined, color: Color(0xFFF57F17), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Nếu AI không đủ tự tin, hệ thống sẽ thông báo thay vì đưa ra kết luận sai.',
                      style: AppTextStyles.caption.copyWith(color: const Color(0xFF5D4037)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _AnalysisStep {
  final IconData icon;
  final String label;
  const _AnalysisStep(this.icon, this.label);
}
