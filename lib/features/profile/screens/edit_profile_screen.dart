import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/auth/session_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/network/api_exception.dart';
import '../../../shared/widgets/error_retry_widget.dart';
import '../../auth/data/auth_validators.dart';
import '../../auth/widgets/auth_widgets.dart';
import '../data/profile_repository.dart';
import '../providers/profile_providers.dart';

class EditProfileScreen extends ConsumerWidget {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppBar(
        title: const Text('Thông tin cá nhân'),
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorRetryWidget(
          error: e,
          onRetry: () => ref.invalidate(profileProvider),
        ),
        data: (p) => _ProfileForm(profile: p),
      ),
    );
  }
}

class _ProfileForm extends ConsumerStatefulWidget {
  const _ProfileForm({required this.profile});

  final FarmerProfile profile;

  @override
  ConsumerState<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<_ProfileForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  DateTime? _dob;
  String? _gender;
  bool _isSubmitting = false;
  String _error = '';

  static final _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.profile.fullName);
    _dob = widget.profile.dateOfBirth;
    _gender = widget.profile.gender;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 30),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Chọn ngày sinh',
      cancelText: 'Huỷ',
      confirmText: 'Chọn',
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _submit() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _error = '';
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      final updated = await ref.read(profileRepositoryProvider).updateProfile(
            fullName: _nameCtrl.text,
            dateOfBirth: _dob,
            gender: _gender,
          );
      // Tên hiển thị ở Hồ sơ lấy từ phiên: cập nhật theo.
      final user = ref.read(sessionProvider).user;
      if (user != null) {
        ref.read(sessionProvider.notifier).updateUser(SessionUser(
              id: user.id,
              fullName: updated.fullName,
              role: user.role,
              phoneNumber: user.phoneNumber,
              email: user.email,
              phoneVerified: user.phoneVerified,
              emailVerified: user.emailVerified,
            ));
      }
      ref.invalidate(profileProvider);
      messenger.showSnackBar(
          const SnackBar(content: Text('Đã cập nhật thông tin cá nhân.')));
      if (mounted) context.canPop() ? context.pop() : null;
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    final initials = SessionUser(id: '', fullName: _nameCtrl.text, role: '').initials;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2), width: 4),
                ),
                alignment: Alignment.center,
                child: Text(initials,
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 32)),
              ),
            ),
            if (p.customerGroup != null) ...[
              const SizedBox(height: 12),
              Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('Nhóm khách hàng: ${p.customerGroup!.name}',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.primary)),
                ),
              ),
            ],
            const SizedBox(height: 28),
            _label('Họ và tên'),
            TextFormField(
              key: const Key('profile_name'),
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() {}),
              decoration:
                  const InputDecoration(prefixIcon: Icon(Icons.person_outline)),
              validator: AuthValidators.fullName,
            ),
            const SizedBox(height: 16),
            _label('Số điện thoại'),
            _ReadOnlyField(
              fieldKey: const Key('profile_phone'),
              icon: Icons.phone_android_outlined,
              value: p.phoneNumber ?? 'Chưa có',
            ),
            const SizedBox(height: 16),
            _label('Email'),
            _ReadOnlyField(
              fieldKey: const Key('profile_email'),
              icon: Icons.mail_outline,
              value: p.email ?? 'Chưa có',
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Số điện thoại và email gắn với tài khoản nên chưa thể thay đổi tại đây.',
                style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
              ),
            ),
            const SizedBox(height: 16),
            _label('Ngày sinh'),
            InkWell(
              key: const Key('profile_dob'),
              borderRadius: BorderRadius.circular(12),
              onTap: _pickDate,
              child: InputDecorator(
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.cake_outlined),
                  suffixIcon: _dob == null
                      ? null
                      : IconButton(
                          tooltip: 'Xoá ngày sinh',
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => setState(() => _dob = null),
                        ),
                ),
                child: Text(
                  _dob == null ? 'Chưa chọn' : _dateFormat.format(_dob!),
                  style: AppTextStyles.bodyMedium.copyWith(
                      color: _dob == null
                          ? AppColors.textMuted
                          : AppColors.textPrimary),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _label('Giới tính'),
            Wrap(
              spacing: 8,
              children: [
                for (final g in Genders.all)
                  ChoiceChip(
                    key: Key('gender_$g'),
                    label: Text(Genders.label(g)),
                    selected: _gender == g,
                    selectedColor: AppColors.primaryLight,
                    // Bấm lại để bỏ chọn (giới tính là tuỳ chọn).
                    onSelected: (sel) => setState(() => _gender = sel ? g : null),
                  ),
              ],
            ),
            if (_error.isNotEmpty) ...[
              const SizedBox(height: 16),
              AuthBanner(_error),
            ],
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: AuthSubmitButton(
                label: 'Lưu thay đổi',
                isLoading: _isSubmitting,
                onPressed: _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: AppTextStyles.labelLarge
                .copyWith(color: AppColors.textSecondary)),
      );
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField(
      {required this.fieldKey, required this.icon, required this.value});

  final Key fieldKey;
  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      key: fieldKey,
      decoration: InputDecoration(
        prefixIcon: Icon(icon),
        fillColor: AppColors.surfaceSecondary,
      ),
      child: Text(value,
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
    );
  }
}
