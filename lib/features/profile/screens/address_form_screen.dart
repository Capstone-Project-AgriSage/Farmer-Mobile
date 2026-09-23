import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

class AddressFormScreen extends StatefulWidget {
  final String? addressId;
  const AddressFormScreen({super.key, this.addressId});

  @override
  State<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends State<AddressFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isDefault = false;

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.addressId != null;

    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppBar(
        title: Text(isEditing ? 'Sửa địa chỉ' : 'Thêm địa chỉ mới'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Liên hệ'),
              _buildTextField('Họ và tên', placeholder: 'Nhập họ và tên'),
              const SizedBox(height: 16),
              _buildTextField('Số điện thoại', placeholder: 'Nhập số điện thoại', keyboardType: TextInputType.phone),
              
              const SizedBox(height: 24),
              _buildSectionTitle('Địa chỉ'),
              _buildTextField('Tỉnh/Thành phố', placeholder: 'VD: Cần Thơ'),
              const SizedBox(height: 16),
              _buildTextField('Quận/Huyện', placeholder: 'VD: Thới Lai'),
              const SizedBox(height: 16),
              _buildTextField('Phường/Xã', placeholder: 'VD: Thới Tân'),
              const SizedBox(height: 16),
              _buildTextField('Tên đường, Tòa nhà, Số nhà', placeholder: 'VD: 123 Ấp Thới Phước'),
              
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Đặt làm địa chỉ mặc định', style: AppTextStyles.bodyMedium),
                    Switch(
                      value: _isDefault,
                      onChanged: (val) {
                        setState(() {
                          _isDefault = val;
                        });
                      },
                      activeColor: AppColors.primary,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Lưu địa chỉ thành công', style: TextStyle(color: Colors.white)),
                  backgroundColor: AppColors.statusSuccess,
                ));
                context.pop();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Lưu địa chỉ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title, style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold, color: AppColors.textMuted)),
    );
  }

  Widget _buildTextField(String label, {String? placeholder, TextInputType keyboardType = TextInputType.text}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextFormField(
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: placeholder,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.borderSubtle)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.borderSubtle)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary)),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Vui lòng nhập $label';
            }
            return null;
          },
        ),
      ],
    );
  }
}
