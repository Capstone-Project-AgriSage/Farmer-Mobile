import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/network/api_exception.dart';
import '../../../data/models/address.dart';
import '../../../shared/widgets/error_retry_widget.dart';
import '../../auth/data/auth_validators.dart';
import '../../auth/widgets/auth_widgets.dart';
import '../providers/profile_providers.dart';

class AddressFormScreen extends ConsumerWidget {
  /// null = thêm mới; có id = sửa địa chỉ đó.
  final String? addressId;
  const AddressFormScreen({super.key, this.addressId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEditing = addressId != null;
    final title = isEditing ? 'Sửa địa chỉ' : 'Thêm địa chỉ mới';

    Widget body;
    if (!isEditing) {
      body = const _AddressForm();
    } else {
      body = ref.watch(addressesProvider).when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ErrorRetryWidget(
              error: e,
              onRetry: () => ref.invalidate(addressesProvider),
            ),
            data: (list) {
              final found = list.where((a) => a.id == addressId);
              if (found.isEmpty) {
                return ErrorRetryWidget(
                  error: const ApiException(
                      kind: ApiErrorKind.notFound,
                      message: 'Địa chỉ này không còn tồn tại.'),
                  onRetry: () => ref.invalidate(addressesProvider),
                );
              }
              return _AddressForm(existing: found.first);
            },
          );
    }

    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppBar(title: Text(title), centerTitle: true),
      body: body,
    );
  }
}

class _AddressForm extends ConsumerStatefulWidget {
  const _AddressForm({this.existing});

  final Address? existing;

  @override
  ConsumerState<_AddressForm> createState() => _AddressFormState();
}

class _AddressFormState extends ConsumerState<_AddressForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _province;
  late final TextEditingController _district;
  late final TextEditingController _ward;
  late final TextEditingController _line;
  late String _type;
  late bool _isDefault;
  bool _isSubmitting = false;
  String _error = '';

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final a = widget.existing;
    _name = TextEditingController(text: a?.recipientName);
    _phone = TextEditingController(text: a?.recipientPhone);
    _province = TextEditingController(text: a?.province);
    _district = TextEditingController(text: a?.district);
    _ward = TextEditingController(text: a?.ward);
    _line = TextEditingController(text: a?.addressLine);
    _type = a?.addressType ?? AddressType.home;
    _isDefault = a?.isDefault ?? false;
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _province, _district, _ward, _line]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _required(String label, String? v, {int max = 150}) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Vui lòng nhập $label';
    return s.length > max ? '$label tối đa $max ký tự' : null;
  }

  String? _optional(String label, String? v) =>
      (v?.trim().length ?? 0) > 150 ? '$label tối đa 150 ký tự' : null;

  Future<void> _submit() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _error = '';
    });
    final messenger = ScaffoldMessenger.of(context);
    final input = AddressInput(
      recipientName: _name.text,
      // Gửi số đã chuẩn hoá cho đồng nhất.
      recipientPhone: AuthValidators.normalizePhone(_phone.text)!,
      addressLine: _line.text,
      province: _province.text,
      district: _district.text,
      ward: _ward.text,
      addressType: _type,
      isDefault: _isDefault,
    );
    try {
      final notifier = ref.read(addressesProvider.notifier);
      if (_isEditing) {
        await notifier.edit(widget.existing!.id, input);
      } else {
        await notifier.create(input);
      }
      messenger.showSnackBar(
          const SnackBar(content: Text('Đã lưu địa chỉ.')));
      if (mounted && context.canPop()) context.pop();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Địa chỉ đang là mặc định thì không bỏ cờ được bằng form (backend giữ
    // nguyên); muốn đổi hãy đặt địa chỉ khác làm mặc định.
    final lockDefault = widget.existing?.isDefault ?? false;

    return Form(
      key: _formKey,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _section('Liên hệ'),
                  _field('addr_name', 'Họ và tên người nhận', _name,
                      hint: 'Nhập họ và tên',
                      validator: (v) => _required('họ và tên', v)),
                  const SizedBox(height: 16),
                  _field('addr_phone', 'Số điện thoại', _phone,
                      hint: 'Nhập số điện thoại',
                      keyboardType: TextInputType.phone,
                      validator: AuthValidators.phone),
                  const SizedBox(height: 24),
                  _section('Địa chỉ'),
                  _field('addr_province', 'Tỉnh/Thành phố', _province,
                      hint: 'VD: Cần Thơ',
                      validator: (v) => _required('tỉnh/thành phố', v)),
                  const SizedBox(height: 16),
                  _field('addr_district', 'Quận/Huyện (tuỳ chọn)', _district,
                      hint: 'VD: Thới Lai',
                      validator: (v) => _optional('Quận/huyện', v)),
                  const SizedBox(height: 16),
                  _field('addr_ward', 'Phường/Xã (tuỳ chọn)', _ward,
                      hint: 'VD: Thới Tân',
                      validator: (v) => _optional('Phường/xã', v)),
                  const SizedBox(height: 16),
                  _field('addr_line', 'Tên đường, Tòa nhà, Số nhà', _line,
                      hint: 'VD: 123 Ấp Thới Phước',
                      maxLines: 2,
                      validator: (v) => _required('địa chỉ', v, max: 500)),
                  const SizedBox(height: 24),
                  _section('Loại địa chỉ'),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final t in AddressType.all)
                        ChoiceChip(
                          key: Key('addr_type_$t'),
                          label: Text(AddressType.label(t)),
                          selected: _type == t,
                          selectedColor: AppColors.primaryLight,
                          onSelected: (_) => setState(() => _type = t),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Đặt làm địa chỉ mặc định',
                                  style: AppTextStyles.bodyMedium),
                              if (lockDefault)
                                Text(
                                    'Hiện là địa chỉ mặc định. Muốn đổi, hãy đặt địa chỉ khác làm mặc định.',
                                    style: AppTextStyles.caption
                                        .copyWith(color: AppColors.textMuted)),
                              if (!_isEditing)
                                Text('Địa chỉ đầu tiên luôn là mặc định.',
                                    style: AppTextStyles.caption
                                        .copyWith(color: AppColors.textMuted)),
                            ],
                          ),
                        ),
                        Switch(
                          key: const Key('addr_default'),
                          value: _isDefault,
                          activeThumbColor: AppColors.primary,
                          onChanged: lockDefault
                              ? null
                              : (v) => setState(() => _isDefault = v),
                        ),
                      ],
                    ),
                  ),
                  if (_error.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    AuthBanner(_error),
                  ],
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: AuthSubmitButton(
                label: 'Lưu địa chỉ',
                isLoading: _isSubmitting,
                onPressed: _submit,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(title,
            style: AppTextStyles.caption
                .copyWith(fontWeight: FontWeight.bold, color: AppColors.textMuted)),
      );

  Widget _field(
    String key,
    String label,
    TextEditingController controller, {
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    required String? Function(String?) validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextFormField(
          key: Key(key),
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(hintText: hint),
          validator: validator,
        ),
      ],
    );
  }
}
