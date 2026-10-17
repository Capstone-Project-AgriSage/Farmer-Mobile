import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/network/api_exception.dart';
import '../data/diagnosis_repository.dart';
import '../../home/providers/home_providers.dart';

/// Chụp hoặc chọn ảnh lá lúa, thêm ghi chú rồi gửi cho chuyên gia.
class ImageCaptureScreen extends ConsumerStatefulWidget {
  const ImageCaptureScreen({super.key});

  @override
  ConsumerState<ImageCaptureScreen> createState() => _ImageCaptureScreenState();
}

class _ImageCaptureScreenState extends ConsumerState<ImageCaptureScreen> {
  final _note = TextEditingController();
  PickedPhoto? _photo;
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

  Future<void> _send() async {
    final photo = _photo;
    if (photo == null || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final created =
          await ref.read(diagnosisRepositoryProvider).create(photo: photo, note: _note.text);
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
    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppBar(
        title: const Text('Chụp ảnh lá lúa'),
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
                                  child: const Icon(Icons.add_a_photo_outlined,
                                      size: 32, color: AppColors.primary),
                                ),
                                const SizedBox(height: 16),
                                Text('Chạm để chụp ảnh lá lúa',
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
                      labelText: 'Ghi chú cho chuyên gia (tuỳ chọn)',
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
                            'Ảnh được gửi cho chuyên gia của cửa hàng xem và kết luận. Kết quả cùng gợi ý điều trị sẽ hiện trong mục Lịch sử sau khi chuyên gia xác nhận.',
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
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send, size: 20),
                    label: Text(_sending ? 'Đang gửi ảnh...' : 'Gửi ảnh cho chuyên gia'),
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

/// Cách chụp để AI và chuyên gia nhận đúng bệnh. Model chỉ học từ ảnh chụp gần một lá: ảnh cả cây hay cả ruộng
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
