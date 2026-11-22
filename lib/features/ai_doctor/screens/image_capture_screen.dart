import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/network/api_exception.dart';
import '../data/crops.dart';
import '../data/diagnosis_repository.dart';
import '../providers/diagnosis_providers.dart';
import '../../home/providers/home_providers.dart';

/// Chọn cây trồng, chụp hoặc chọn ảnh lá của cây đó, thêm ghi chú rồi gửi cho AI phân tích. Biết cây trước giúp AI
/// chỉ chọn trong các bệnh của cây đó (AI_DIAGNOSIS.md 2.2).
class ImageCaptureScreen extends ConsumerStatefulWidget {
  const ImageCaptureScreen({super.key});

  @override
  ConsumerState<ImageCaptureScreen> createState() => _ImageCaptureScreenState();
}

class _ImageCaptureScreenState extends ConsumerState<ImageCaptureScreen> {
  final _note = TextEditingController();
  PickedPhoto? _photo;

  /// Cây người dùng bấm chọn trên màn này; null = chưa bấm (khi đó dùng cây lần trước, hoặc cây duy nhất).
  String? _crop;
  String? _error;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    // Camera có thể làm Android đóng app lúc đang chụp: lấy lại ảnh vừa chụp khi app mở lại.
    WidgetsBinding.instance.addPostFrameCallback((_) => _recoverLost());
  }

  Future<void> _recoverLost() async {
    final p = await ref.read(photoPickerProvider).recoverLost();
    if (p == null || !mounted || _photo != null) return;
    _accept(p);
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _pick(PhotoSource source) async {
    if (_sending) return;
    try {
      final p = await ref.read(photoPickerProvider).pick(source);
      if (p == null || !mounted) return;
      _accept(p);
    } on PhotoPickerException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  void _accept(PickedPhoto p) {
    final problem = DiagnosisRepository.validatePhoto(p);
    setState(() {
      if (problem == null) {
        _photo = p;
        _error = null;
      } else {
        _error = problem;
      }
    });
  }

  /// Cây sẽ gửi kèm ảnh, chỉ trong các cây server cho phép lúc này.
  String? _selectedCrop(List<DiagnosisCrop> crops) {
    bool offered(String? code) => code != null && crops.any((c) => c.code == code);
    if (offered(_crop)) return _crop;
    final last = ref.read(lastCropProvider);
    if (offered(last)) return last;
    return crops.length == 1 ? crops.first.code : null;
  }

  void _pickCrop(String code) {
    if (_sending) return;
    setState(() {
      _crop = code;
      _error = null;
    });
    ref.read(lastCropProvider.notifier).save(code);
  }

  Future<void> _send(String crop) async {
    final photo = _photo;
    if (photo == null || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final created = await ref
          .read(diagnosisRepositoryProvider)
          .create(photo: photo, note: _note.text, cropType: crop);
      ref.read(lastCropProvider.notifier).save(crop);
      if (!mounted) return;
      invalidateDiagnoses(ref);
      context.pushReplacement('/ai-scan/case/${created.id}');
    } catch (error) {
      // Cả lỗi ngoài dự kiến (đọc file, dữ liệu sai dạng...) cũng phải mở lại nút gửi.
      final e = ApiException.from(error);
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final photo = _photo;
    final crops = ref.watch(diagnosisCropsProvider);
    final crop = crops.hasValue ? _selectedCrop(crops.requireValue) : null;
    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppBar(
        title: const Text('Chụp ảnh lá cây'),
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _StepTitle(number: '1', text: 'Chọn cây trồng'),
                  const SizedBox(height: 10),
                  _CropPicker(
                    crops: crops,
                    selected: crop,
                    enabled: !_sending,
                    onPick: _pickCrop,
                    onRetry: () => ref.invalidate(diagnosisCropsProvider),
                  ),
                  const SizedBox(height: 20),
                  _StepTitle(
                      number: '2',
                      text: crop == null ? 'Chụp ảnh lá cây' : 'Chụp ảnh ${Crops.leafOf(crop)}'),
                  const SizedBox(height: 10),
                  GestureDetector(
                    key: const Key('cap_preview'),
                    onTap: _sending ? null : () => _pick(PhotoSource.camera),
                    child: Container(
                      height: 280,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: photo != null
                            ? Border.all(color: AppColors.primary, width: 2)
                            : null,
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.045),
                              blurRadius: 14,
                              offset: const Offset(0, 4)),
                        ],
                      ),
                      child: photo != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(22),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.file(
                                    File(photo.path),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Center(
                                        child: Icon(Icons.image_outlined,
                                            size: 48, color: AppColors.borderStrong)),
                                  ),
                                  Positioned(
                                    top: 12,
                                    right: 12,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.refresh, color: Colors.white, size: 14),
                                          SizedBox(width: 4),
                                          Text('Đổi ảnh',
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600)),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 12,
                                    left: 12,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryLight,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.check_circle,
                                              color: AppColors.primary, size: 14),
                                          const SizedBox(width: 4),
                                          Text('Ảnh sẵn sàng',
                                              style: AppTextStyles.caption.copyWith(
                                                  color: AppColors.primary,
                                                  fontWeight: FontWeight.w600)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 72,
                                  height: 72,
                                  decoration: const BoxDecoration(
                                    color: AppColors.primaryLight,
                                    shape: BoxShape.circle,
                                  ),
                                  // Icon cân đối: add_a_photo có dấu cộng ở góc nên trông lệch khỏi tâm vòng tròn.
                                  alignment: Alignment.center,
                                  child: const Icon(Icons.photo_camera_outlined,
                                      size: 34, color: AppColors.primary),
                                ),
                                const SizedBox(height: 16),
                                Text(crop == null ? 'Chạm để chụp ảnh lá cây' : 'Chạm để chụp ảnh ${Crops.leafOf(crop)}',
                                    key: const Key('cap_preview_hint'),
                                    textAlign: TextAlign.center,
                                    style: AppTextStyles.bodyMedium
                                        .copyWith(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 6),
                                Text('Hoặc chọn ảnh từ thư viện bên dưới',
                                    style: AppTextStyles.caption),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _ActionButton(
                          key: const Key('cap_camera'),
                          icon: Icons.camera_alt,
                          label: 'Chụp ảnh mới',
                          color: AppColors.primary,
                          onTap: () => _pick(PhotoSource.camera),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ActionButton(
                          key: const Key('cap_gallery'),
                          icon: Icons.photo_library_outlined,
                          label: 'Chọn từ thư viện',
                          color: const Color(0xFF1565C0),
                          onTap: () => _pick(PhotoSource.gallery),
                        ),
                      ),
                    ],
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      key: const Key('cap_error'),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.statusErrorSurface,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(_error!,
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.statusError)),
                    ),
                  ],
                  const SizedBox(height: 16),
                  // Ngay dưới nút chụp để người dùng đọc trước khi chụp.
                  const _CaptureTips(),
                  const SizedBox(height: 16),
                  TextField(
                    key: const Key('cap_note'),
                    controller: _note,
                    enabled: !_sending,
                    maxLines: 3,
                    maxLength: DiagnosisRepository.maxNoteLength,
                    decoration: const InputDecoration(
                      labelText: 'Ghi chú cho AI và cửa hàng (tuỳ chọn)',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.verified_user_outlined,
                            color: Color(0xFFF57F17), size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'AI phân tích ảnh và cho kết quả ngay sau khi gửi. Ảnh và ghi chú được gửi tới dịch vụ AI để phân tích. Kết quả do AI dự đoán, chỉ để tham khảo: hãy hỏi cửa hàng trước khi dùng thuốc.',
                            style: AppTextStyles.caption
                                .copyWith(color: const Color(0xFF5D4037), height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          if (photo != null)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, -6))
                ],
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    key: const Key('cap_send'),
                    onPressed: _sending || crop == null ? null : () => _send(crop),
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send, size: 20),
                    label: Text(_sending
                        ? 'AI đang phân tích...'
                        : crop == null
                            ? 'Chọn cây trồng trước khi gửi'
                            : 'Gửi ảnh để AI chẩn đoán'),
                    style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StepTitle extends StatelessWidget {
  const _StepTitle({required this.number, required this.text});

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
          child: Text(number,
              style: AppTextStyles.caption.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: AppTextStyles.labelLarge)),
      ],
    );
  }
}

/// Các cây gửi ảnh được lúc này (từ server). Đang tải / lỗi / chưa có cây nào đều nói rõ cho người dùng.
class _CropPicker extends StatelessWidget {
  const _CropPicker({
    required this.crops,
    required this.selected,
    required this.enabled,
    required this.onPick,
    required this.onRetry,
  });

  final AsyncValue<List<DiagnosisCrop>> crops;
  final String? selected;
  final bool enabled;
  final ValueChanged<String> onPick;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return crops.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(
            child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
      ),
      error: (e, _) => Container(
        key: const Key('cap_crops_error'),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: AppColors.statusErrorSurface, borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            Expanded(
              child: Text(ApiException.from(e).message,
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.statusError)),
            ),
            TextButton(
                key: const Key('cap_crops_retry'), onPressed: onRetry, child: const Text('Thử lại')),
          ],
        ),
      ),
      data: (items) => items.isEmpty
          ? Text('Chưa có cây nào được chẩn đoán qua ảnh. Hãy hỏi cửa hàng.',
              key: const Key('cap_crops_empty'),
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary))
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in items)
                  ChoiceChip(
                    key: Key('cap_crop_${c.code}'),
                    label: Text(c.name),
                    selected: c.code == selected,
                    showCheckmark: false,
                    selectedColor: AppColors.primaryLight,
                    labelStyle: AppTextStyles.bodySmall.copyWith(
                      color: c.code == selected ? AppColors.primaryDark : AppColors.textSecondary,
                      fontWeight: c.code == selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                    onSelected: enabled ? (_) => onPick(c.code) : null,
                  ),
              ],
            ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionButton(
      {super.key,
      required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.045),
              blurRadius: 14,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 8),
              Text(label,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.labelLarge.copyWith(fontSize: 12)),
            ],
          ),
        ),
        ),
      ),
    );
  }
}

/// Cách chụp để AI nhận đúng bệnh. Model chỉ học từ ảnh chụp gần một lá: ảnh cả cây hay cả ruộng
/// gần như luôn bị nhận sai (AI-Service, research/report.md), nên mẹo nói rõ điều đó.
class _CaptureTips extends StatelessWidget {
  const _CaptureTips();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('cap_tips'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.045),
              blurRadius: 14,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.lightbulb_outline, color: Color(0xFFF57F17), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Chụp thế nào để nhận đúng bệnh', style: AppTextStyles.labelLarge),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const _TipItem(
              number: '1',
              text: 'Chụp một lá bệnh, cách khoảng 15 đến 30 cm, lá chiếm gần hết khung hình'),
          const SizedBox(height: 10),
          const _TipItem(
              number: '2', text: 'Để vết bệnh rõ ở giữa ảnh, giữ máy chắc tay cho ảnh nét'),
          const SizedBox(height: 10),
          const _TipItem(
              number: '3', text: 'Chụp dưới ánh sáng tự nhiên, tránh ngược sáng và bóng che'),
          const SizedBox(height: 10),
          const _TipItem(
              number: '4',
              text: 'Không chụp cả cây hay cả ruộng: ở xa không thấy được vết bệnh'),
        ],
      ),
    );
  }
}

class _TipItem extends StatelessWidget {
  final String number;
  final String text;
  const _TipItem({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
              child: Text(number,
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.primary, fontWeight: FontWeight.bold))),
        ),
        const SizedBox(width: 10),
        Expanded(
            child: Text(text,
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary))),
      ],
    );
  }
}
