import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/debt.dart';
import '../../../data/mock/mock_debts.dart';

class DebtListScreen extends StatefulWidget {
  const DebtListScreen({super.key});

  @override
  State<DebtListScreen> createState() => _DebtListScreenState();
}

class _DebtListScreenState extends State<DebtListScreen> {
  int _selectedFilter = 0;
  final _filters = ['Tất cả', 'Chưa trả', 'Đã trả', 'Quá hạn'];

  List<Debt> get _filteredDebts {
    if (_selectedFilter == 0) return mockDebts;
    if (_selectedFilter == 1) return mockDebts.where((d) => d.status != DebtStatus.paid).toList();
    if (_selectedFilter == 2) return mockDebts.where((d) => d.status == DebtStatus.paid).toList();
    if (_selectedFilter == 3) return mockDebts.where((d) => d.status == DebtStatus.overdue).toList();
    return mockDebts;
  }

  @override
  Widget build(BuildContext context) {
    final debts = _filteredDebts;

    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppBar(
        title: const Text('Danh sách công nợ'),
      ),
      body: Column(
        children: [
          // Filter Tabs
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(_filters.length, (i) {
                  final selected = _selectedFilter == i;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedFilter = i),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected ? AppColors.primaryDark : AppColors.surfaceSubtle,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: selected ? AppColors.primaryDark : AppColors.borderSubtle),
                        ),
                        child: Text(
                          _filters[i],
                          style: AppTextStyles.bodySmall.copyWith(
                            color: selected ? Colors.white : AppColors.textSecondary,
                            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),

          // Count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.list_alt, size: 16, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Text('Có ${debts.length} khoản nợ', style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
              ],
            ),
          ),

          // List
          Expanded(
            child: debts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.inbox_outlined, size: 64, color: AppColors.surfaceDim),
                        const SizedBox(height: 16),
                        Text('Không có dữ liệu', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted)),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: debts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _DebtCard(debt: debts[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _DebtCard extends StatelessWidget {
  final Debt debt;
  const _DebtCard({required this.debt});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/debt/${debt.id}'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderSubtle),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(debt.id, style: AppTextStyles.caption.copyWith(color: AppColors.textMuted, fontWeight: FontWeight.bold)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: debt.status.backgroundColor,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: debt.status.color.withOpacity(0.3)),
                  ),
                  child: Text(
                    debt.status.label,
                    style: TextStyle(color: debt.status.color, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSubtle,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.storefront, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(debt.agentName, style: AppTextStyles.labelLarge),
                      const SizedBox(height: 2),
                      Text(debt.note ?? 'Không có ghi chú', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1, color: AppColors.borderSubtle),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Hạn trả', style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
                    const SizedBox(height: 2),
                    Text(_formatDate(debt.dueDate), style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Số tiền', style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
                    const SizedBox(height: 2),
                    Text(
                      '${_formatPrice(debt.amount)}đ',
                      style: AppTextStyles.labelLarge.copyWith(color: debt.status == DebtStatus.paid ? AppColors.textPrimary : AppColors.statusError),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  String _formatPrice(double price) {
    return price.toInt().toString().replaceAll(RegExp(r'\B(?=(\d{3})+(?!\d))'), '.');
  }
}
