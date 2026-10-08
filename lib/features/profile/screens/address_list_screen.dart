import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/mock/mock_addresses.dart';
import '../../../data/models/address.dart';
import '../../../router/app_router.dart';

class AddressListScreen extends StatefulWidget {
  const AddressListScreen({super.key});

  @override
  State<AddressListScreen> createState() => _AddressListScreenState();
}

class _AddressListScreenState extends State<AddressListScreen> {
  late List<Address> _addresses;

  @override
  void initState() {
    super.initState();
    _addresses = List.from(mockAddresses);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppBar(
        title: const Text('Quản lý địa chỉ'),
        centerTitle: true,
      ),
      body: _addresses.isEmpty
          ? Center(
              child: Text('Bạn chưa có địa chỉ nào', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted)),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _addresses.length,
              itemBuilder: (context, index) {
                final address = _addresses[index];
                return _buildAddressCard(address);
              },
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: () => context.push('${AppRoutes.profile}/addresses/add'),
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('Thêm địa chỉ mới', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddressCard(Address address) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: address.isDefault ? AppColors.primary : AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(address.name, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
                  if (address.isDefault) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(4)),
                      child: const Text('Mặc định', style: TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ],
              ),
              GestureDetector(
                onTap: () => context.push('${AppRoutes.profile}/addresses/edit/${address.id}'),
                child: Text('Sửa', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(address.phone, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(address.fullAddress, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary, height: 1.5)),
        ],
      ),
    );
  }
}
