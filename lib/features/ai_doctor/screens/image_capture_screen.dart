import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/network/app_exception.dart';
import '../../diagnosis/data/diagnosis_photo.dart';
import '../../diagnosis/providers/diagnosis_providers.dart';

/// Choose or take one photo of a rice leaf, add a note if wanted, and send it to the store's specialist.
class ImageCaptureScreen extends ConsumerStatefulWidget {
  const ImageCaptureScreen({super.key});

  @override
  ConsumerState<ImageCaptureScreen> createState() => _ImageCaptureScreenState();
}

class _ImageCaptureScreenState extends ConsumerState<ImageCaptureScreen> {
  static const _noteMaxLength = 1000;

  final _note = TextEditingController();
  DiagnosisPhotoFile? _photo;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    // Android may close the app while the camera is open; the photo taken is then handed back here.
    WidgetsBinding.instance.addPostFrameCallback((_) => _recoverLostPhoto());
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _recoverLostPhoto() async {
    final lost = await ref.read(diagnosisPhotoServiceProvider).recoverLostPhoto();
    if (lost != null && mounted && _photo == null) setState(() => _photo = lost);
  }

  Future<void> _pick(ImageSource source) async {
    if (_sending) return;
    try {
      final photo = await ref.read(diagnosisPhotoServiceProvider).pick(source);
      if (photo != null && mounted) setState(() => _photo = photo);
    } on DiagnosisPhotoException catch (error) {
      _say(error.message);
    }
  }

  Future<void> _send() async {
    final photo = _photo;
    if (photo == null || _sending) return;

    setState(() => _sending = true);
    try {
      final created = await ref.read(diagnosisActionsProvider).send(photo, note: _note.text);
      if (!mounted) return;
      // The photo screen is replaced so that "back" from the result goes to the start page, not to a sent photo.
      context.pushReplacement('/ai-scan/cases/${created.id}');
    } on AppException catch (error) {
      if (mounted) {
        setState(() => _sending = false);
        _say(error.message);
      }
    }
  }

  void _say(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final photo = _photo;

    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppBar(title: const Text('Chụp ảnh lá lúa')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Image Preview Area ─────────────────────────────
                  GestureDetector(
                    onTap: () => _pick(ImageSource.camera),
                    child: Container(
                      height: 280,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: photo != null ? AppColors.primary : AppColors.borderSubtle,
                          width: photo != null ? 2 : 1,
                        ),
                      ),
                      child: photo != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.file(File(photo.path), fit: BoxFit.cover),
                                  Positioned(
                                    top: 12,
                                    right: 12,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.refresh, color: Colors.white, size: 14),
                                          SizedBox(width: 4),
                                          Text('Đổi ảnh', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 12,
                                    left: 12,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryLight,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.check_circle, color: AppColors.primary, size: 14),
                                          const SizedBox(width: 4),
                                          Text('Ảnh sẵn sàng', style: AppTextStyles.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600)),
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
                                  child: const Icon(Icons.add_a_photo_outlined, size: 32, color: AppColors.primary),
                                ),
                                const SizedBox(height: 16),
                                Text('Chạm để chụp ảnh lá lúa', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 6),
                                Text('Hoặc chọn ảnh từ thư viện bên dưới', style: AppTextStyles.caption),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Camera & Gallery Buttons ──────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.camera_alt,
                          label: 'Chụp ảnh mới',
                          color: const Color(0xFF6A1B9A),
                          onTap: () => _pick(ImageSource.camera),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.photo_library_outlined,
                          label: 'Chọn từ thư viện',
                          color: const Color(0xFF1565C0),
                          onTap: () => _pick(ImageSource.gallery),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Note ──────────────────────────────────────────
                  TextField(
                    controller: _note,
                    enabled: !_sending,
                    maxLength: _noteMaxLength,
                    maxLines: 3,
                    minLines: 2,
                    textInputAction: TextInputAction.newline,
                    decoration: const InputDecoration(
                      labelText: 'Ghi chú cho chuyên viên (không bắt buộc)',
                      hintText: 'Ví dụ: lá vàng từ chóp, ruộng sạ được 30 ngày',
                      filled: true,
                      fillColor: Colors.white,
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // ── Tips Panel ────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderSubtle),
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
                            Text('3 mẹo để ảnh dễ chẩn đoán', style: AppTextStyles.labelLarge),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const _TipItem(number: '1', text: 'Chụp rõ nét, đủ ánh sáng tự nhiên'),
                        const SizedBox(height: 10),
                        const _TipItem(number: '2', text: 'Đặt lá bệnh ở giữa khung hình, chụp gần'),
                        const SizedBox(height: 10),
                        const _TipItem(number: '3', text: 'Tránh ảnh bị mờ, ngược sáng hoặc có bóng che'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Safety Notice ─────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(10),
                      border: const Border.fromBorderSide(BorderSide(color: Color(0xFFFFE082))),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.shield_outlined, color: Color(0xFFF57F17), size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Ảnh được gửi tới chuyên viên của đại lý. Kết quả và gợi ý sản phẩm chỉ hiện sau khi chuyên viên xem và xác nhận.',
                            style: AppTextStyles.caption.copyWith(color: const Color(0xFF5D4037), height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),

          // ── Bottom Send Button ──────────────────────────────────
          if (photo != null)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -4))],
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _sending ? null : _send,
                  icon: _sending
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded, size: 20),
                  label: Text(_sending ? 'Đang gửi ảnh...' : 'Gửi ảnh cho chuyên viên'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6A1B9A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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
  const _ActionButton({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 8),
              Text(label, style: AppTextStyles.labelLarge.copyWith(fontSize: 12)),
            ],
          ),
        ),
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
          child: Center(child: Text(number, style: AppTextStyles.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold))),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary))),
      ],
    );
  }
}
