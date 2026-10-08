import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/network/app_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/utils/validators.dart';
import '../data/address_models.dart';
import '../providers/address_providers.dart';

/// The fields of one delivery address. It validates like the backend does and shows the server's own complaint under the
/// right field when it still refuses. [onSubmit] does the saving; the form only reports a failure.
class AddressForm extends StatefulWidget {
  const AddressForm({
    super.key,
    required this.onSubmit,
    this.initial,
    this.initialName = '',
    this.initialPhone = '',
    this.submitLabel = 'Lưu địa chỉ',
    this.defaultChecked = false,
  });

  final Future<void> Function(AddressInput input) onSubmit;

  /// An address being edited; null for a new one.
  final Address? initial;

  /// Pre-filled recipient for a new address (the farmer themself, who can change it).
  final String initialName;
  final String initialPhone;
  final String submitLabel;
  final bool defaultChecked;

  @override
  State<AddressForm> createState() => _AddressFormState();
}

class _AddressFormState extends State<AddressForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _line;
  late final TextEditingController _ward;
  late final TextEditingController _district;
  late final TextEditingController _province;
  late String _type;
  late bool _isDefault;
  bool _busy = false;
  AppException? _error;

  @override
  void initState() {
    super.initState();
    final a = widget.initial;
    _name = TextEditingController(text: a?.recipientName ?? widget.initialName);
    _phone = TextEditingController(text: a?.recipientPhone ?? widget.initialPhone);
    _line = TextEditingController(text: a?.addressLine ?? '');
    _ward = TextEditingController(text: a?.ward ?? '');
    _district = TextEditingController(text: a?.district ?? '');
    _province = TextEditingController(text: a?.province ?? '');
    _type = a?.addressType ?? AddressType.home;
    _isDefault = a?.isDefault ?? widget.defaultChecked;
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _line, _ward, _district, _province]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _maxLength(String? value, int max, String label) =>
      (value != null && value.trim().length > max) ? '$label tối đa $max ký tự' : null;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    final input = AddressInput(
      recipientName: _name.text,
      recipientPhone: stripPhoneSeparators(_phone.text),
      addressLine: _line.text,
      province: _province.text,
      ward: _ward.text,
      district: _district.text,
      latitude: widget.initial?.latitude,
      longitude: widget.initial?.longitude,
      addressType: _type,
      isDefault: _isDefault,
    );
    try {
      await widget.onSubmit(input);
    } on AppException catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _name,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(labelText: 'Người nhận', errorText: _error?.fieldError('recipientName')),
            validator: (v) => validateRequired(v, 'Vui lòng nhập tên người nhận') ?? _maxLength(v, 150, 'Tên'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Số điện thoại người nhận',
              errorText: _error?.fieldError('recipientPhone'),
            ),
            validator: validateVnPhone,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _line,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Số nhà, ấp / thôn, đường',
              errorText: _error?.fieldError('addressLine'),
            ),
            validator: (v) => validateRequired(v, 'Vui lòng nhập địa chỉ') ?? _maxLength(v, 500, 'Địa chỉ'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _ward,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Xã / Phường'),
                  validator: (v) => _maxLength(v, 150, 'Xã / Phường'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _district,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Quận / Huyện'),
                  validator: (v) => _maxLength(v, 150, 'Quận / Huyện'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _province,
            textInputAction: TextInputAction.done,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(labelText: 'Tỉnh / Thành phố', errorText: _error?.fieldError('province')),
            validator: (v) => validateRequired(v, 'Vui lòng nhập tỉnh / thành phố') ?? _maxLength(v, 150, 'Tỉnh / Thành phố'),
          ),
          const SizedBox(height: 16),
          Text('Loại địa chỉ', style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final type in AddressType.all)
                ChoiceChip(
                  label: Text(AddressType.label(type)),
                  selected: _type == type,
                  onSelected: (_) => setState(() => _type = type),
                  selectedColor: AppColors.primaryLight,
                ),
            ],
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Đặt làm địa chỉ mặc định', style: AppTextStyles.bodySmall),
            value: _isDefault,
            onChanged: (value) => setState(() => _isDefault = value),
          ),
          if (_error != null) ...[
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: AppColors.statusErrorSurface, borderRadius: BorderRadius.circular(8)),
              child: Text(_error!.message, style: AppTextStyles.bodySmall.copyWith(color: AppColors.statusError)),
            ),
          ],
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(widget.submitLabel),
          ),
        ],
      ),
    );
  }
}

/// Opens the new-address form in a bottom sheet and saves the address to the farmer's book. Returns the saved address,
/// or null when the farmer closed the sheet.
Future<Address?> showNewAddressSheet(BuildContext context, {bool makeDefault = false}) {
  return showModalBottomSheet<Address>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => Consumer(
      builder: (_, ref, __) {
        final user = ref.read(sessionManagerProvider).user;
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(sheetContext).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Thêm địa chỉ giao hàng', style: AppTextStyles.h4),
                const SizedBox(height: 16),
                AddressForm(
                  initialName: user?.fullName ?? '',
                  initialPhone: user?.phoneNumber ?? '',
                  defaultChecked: makeDefault,
                  onSubmit: (input) async {
                    final created = await ref.read(addressBookProvider.notifier).create(input);
                    if (sheetContext.mounted) Navigator.of(sheetContext).pop(created);
                  },
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
