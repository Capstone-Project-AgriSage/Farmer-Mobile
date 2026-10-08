import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/network/app_exception.dart';
import '../../../core/utils/validators.dart';
import '../../../core/utils/vn_time.dart';
import '../../../core/widgets/error_retry_view.dart';
import '../data/profile_models.dart';
import '../providers/profile_providers.dart';

/// Thông tin cá nhân: họ tên, ngày sinh, giới tính. Số điện thoại và email thuộc về tài khoản nên chỉ xem.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  DateTime? _dob;
  String? _gender;
  bool _seeded = false;
  bool _busy = false;
  AppException? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _seed(FarmerProfile profile) {
    if (_seeded) return;
    _seeded = true;
    _name.text = profile.fullName;
    _dob = profile.dateOfBirth;
    _gender = profile.gender;
  }

  Future<void> _pickDate() async {
    final today = vnToday();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(1990, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime(today.year, today.month, today.day),
      helpText: 'Chọn ngày sinh',
    );
    if (picked != null) setState(() => _dob = DateTime.utc(picked.year, picked.month, picked.day));
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(profileActionsProvider).save(ProfileUpdate(fullName: _name.text, dateOfBirth: _dob, gender: _gender));
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Đã lưu thông tin cá nhân.')));
      if (context.canPop()) context.pop();
    } on AppException catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);

    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppBar(title: const Text('Thông tin cá nhân')),
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorRetryView(error: error, onRetry: () => ref.invalidate(profileProvider)),
        data: (data) {
          _seed(data);
          return _buildForm(data);
        },
      ),
    );
  }

  Widget _buildForm(FarmerProfile profile) {
    return Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(labelText: 'Họ và tên', errorText: _error?.fieldError('fullName')),
            validator: validateFullName,
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(10),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Ngày sinh',
                suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
                errorText: _error?.fieldError('dateOfBirth'),
              ),
              child: Text(
                _dob == null ? 'Chưa cập nhật' : formatVnDate(_dob),
                style: AppTextStyles.bodyMedium.copyWith(color: _dob == null ? AppColors.textMuted : AppColors.textPrimary),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Giới tính', style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final gender in Gender.all)
                ChoiceChip(
                  label: Text(Gender.label(gender)),
                  selected: _gender == gender,
                  onSelected: (_) => setState(() => _gender = gender),
                  selectedColor: AppColors.primaryLight,
                ),
            ],
          ),
          const SizedBox(height: 24),
          _ReadOnlyField(label: 'Số điện thoại', value: profile.phoneNumber ?? 'Chưa có'),
          if (profile.email != null) ...[
            const SizedBox(height: 12),
            _ReadOnlyField(label: 'Email', value: profile.email!),
          ],
          if (profile.customerGroupName != null) ...[
            const SizedBox(height: 12),
            _ReadOnlyField(label: 'Nhóm khách hàng', value: profile.customerGroupName!),
          ],
          const SizedBox(height: 8),
          Text(
            'Số điện thoại và email gắn với tài khoản, nên chưa đổi được trong ứng dụng. Bác liên hệ cửa hàng nếu cần đổi.',
            style: AppTextStyles.caption.copyWith(color: AppColors.textMuted, height: 1.4),
          ),
          if (_error != null && _error!.fieldErrors.isEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.statusErrorSurface, borderRadius: BorderRadius.circular(8)),
              child: Text(_error!.message, style: AppTextStyles.bodySmall.copyWith(color: AppColors.statusError)),
            ),
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _busy ? null : _save,
            child: _busy
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Lưu thay đổi'),
          ),
        ],
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label, enabled: false),
      child: Text(value, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
    );
  }
}
