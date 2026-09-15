import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/debt.dart';
import '../../../router/app_router.dart';

class DebtOverviewScreen extends StatefulWidget {
  const DebtOverviewScreen({super.key});
  @override State<DebtOverviewScreen> createState() => _DebtOverviewScreenState();
}

class _DebtOverviewScreenState extends State<DebtOverviewScreen> {
  int _selectedStatus = 0;
  final _statusLabels = ['Tất cả', 'Chờ xác nhận', 'Đang nợ', 'Quá hạn', 'Đã trả'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppBar(
        title: Text('Công nợ', style: AppTextStyles.h3),
        actions: [
          IconButton(icon: const Icon(Icons.history_outlined, color: AppColors.textPrimary), onPressed: () => context.push('/debt/history')),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16), 
        child: Column(
          children: [
            // Credit limit card (Similar to AI Banner)
            Container(
              padding: const EdgeInsets.all(20),
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF1B5E20), // Dark green
                borderRadius: BorderRadius.circular(16),
                image: DecorationImage(
                  image: const NetworkImage('https://cdn-icons-png.flaticon.com/512/3233/3233483.png'), // placeholder wallet icon
                  fit: BoxFit.none,
                  alignment: Alignment.centerRight,
                  colorFilter: ColorFilter.mode(Colors.white.withOpacity(0.05), BlendMode.dstIn),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                    child: const Text('Hạn mức tín dụng mùa vụ', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
                  ),
                  const SizedBox(height: 16),
                  const Text('50.000.000 đ', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Đang nợ', style: TextStyle(color: Colors.white70, fontSize: 12)),
                            const SizedBox(height: 4),
                            const Text('0 đ', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 30, color: Colors.white24),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Còn lại', style: TextStyle(color: Colors.white70, fontSize: 12)),
                            const SizedBox(height: 4),
                            const Text('50.000.000 đ', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // Status Filters (Pills)
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal, 
                itemCount: _statusLabels.length, 
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final isActive = _selectedStatus == i;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedStatus = i),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isActive ? const Color(0xFF1B5E20) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isActive ? const Color(0xFF1B5E20) : AppColors.borderSubtle),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _statusLabels[i],
                        style: AppTextStyles.bodySmall.copyWith(
                          color: isActive ? Colors.white : AppColors.textSecondary,
                          fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),

            // Debt list (White cards)
            ListView.separated(
              shrinkWrap: true, 
              physics: const NeverScrollableScrollPhysics(), 
              itemCount: 3,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => context.push('/debt/debt-'),
                child: Container(
                  padding: const EdgeInsets.all(16), 
                  decoration: BoxDecoration(
                    color: Colors.white, 
                    borderRadius: BorderRadius.circular(16), 
                    border: Border.all(color: AppColors.borderSubtle),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4))],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.receipt_long, size: 20, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Text('#CN-884$i', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: i == 0 ? Colors.orange.shade50 : AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              i == 0 ? 'Chờ xác nhận' : 'Đang nợ',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: i == 0 ? Colors.orange.shade800 : AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Đại lý ABC', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                          Text('2.500.000đ', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Ngày lập: 01/09/2026', style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
                          Row(
                            children: [
                              Text('Chi tiết', style: AppTextStyles.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                              const Icon(Icons.chevron_right, size: 16, color: AppColors.primary),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}