import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../router/app_router.dart';
import '../../../shared/widgets/empty_data_widget.dart';
import '../../../shared/widgets/error_retry_widget.dart';
import '../../orders/widgets/order_widgets.dart' show StatusChip;
import '../../products/widgets/product_widgets.dart' show CartIconButton;
import '../data/advisory_models.dart';
import '../data/advisory_repository.dart';
import '../providers/advisory_providers.dart';

/// Nông dân đã biết vấn đề trên ruộng: gõ tên bệnh, sâu, triệu chứng (không cần dấu) hoặc lọc theo loại, rồi chọn
/// để xem sản phẩm gợi ý. Chưa biết bệnh gì thì có lối sang chụp ảnh.
class AdvisorySearchScreen extends ConsumerStatefulWidget {
  const AdvisorySearchScreen({super.key});

  /// Đợi người dùng gõ xong mới gọi server.
  static const searchDebounce = Duration(milliseconds: 400);

  @override
  ConsumerState<AdvisorySearchScreen> createState() => _AdvisorySearchScreenState();
}

class _AdvisorySearchScreenState extends ConsumerState<AdvisorySearchScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  String _search = '';
  String? _type;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    setState(() {}); // hiện/ẩn nút xoá
    _debounce = Timer(AdvisorySearchScreen.searchDebounce, () {
      if (mounted) setState(() => _search = value.trim());
    });
  }

  void _clear() {
    _debounce?.cancel();
    _searchCtrl.clear();
    setState(() => _search = '');
  }

  @override
  Widget build(BuildContext context) {
    final query = AdvisoryProblemQuery(search: _search, type: _type);
    final problems = ref.watch(advisoryProblemsProvider(query));

    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        toolbarHeight: 64,
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tư vấn vật tư', style: AppTextStyles.h2.copyWith(height: 1.2)),
            Text('Chọn vấn đề trên ruộng lúa',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceSubtle,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const CartIconButton(),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 6)),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
            child: Column(
              children: [
                TextField(
                  key: const Key('advisory_search'),
                  controller: _searchCtrl,
                  onChanged: _onChanged,
                  onSubmitted: (v) {
                    _debounce?.cancel();
                    setState(() => _search = v.trim());
                  },
                  textInputAction: TextInputAction.search,
                  maxLength: AdvisoryRepository.maxSearchLength,
                  decoration: InputDecoration(
                    hintText: 'Gõ vấn đề: đạo ôn, vàng lá, rầy nâu...',
                    counterText: '',
                    filled: true,
                    fillColor: AppColors.surfaceSubtle,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppColors.borderSubtle),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                    ),
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted),
                    suffixIcon: _searchCtrl.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Xoá tìm kiếm',
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: _clear,
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: ProblemType.filters.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final type = ProblemType.filters[i];
                      return ChoiceChip(
                        key: Key('advisory_type_${type ?? 'all'}'),
                        label: Text(ProblemType.label(type)),
                        selected: _type == type,
                        showCheckmark: false,
                        selectedColor: AppColors.primaryLight,
                        labelStyle: AppTextStyles.bodySmall.copyWith(
                          color: _type == type ? AppColors.primaryDark : AppColors.textSecondary,
                          fontWeight: _type == type ? FontWeight.w700 : FontWeight.w500,
                        ),
                        onSelected: (_) => setState(() => _type = type),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: problems.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorRetryWidget(error: e, onRetry: () => ref.invalidate(advisoryProblemsProvider(query))),
              data: (items) => _ProblemList(items: items, searching: _search.isNotEmpty || _type != null),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProblemList extends StatelessWidget {
  const _ProblemList({required this.items, required this.searching});

  final List<AdvisoryProblem> items;
  final bool searching;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        const _PhotoShortcut(),
        const SizedBox(height: 12),
        if (items.isEmpty)
          SizedBox(
            height: 280,
            child: EmptyDataWidget(
              key: const Key('advisory_empty'),
              message: searching
                  ? 'Không tìm thấy vấn đề phù hợp. Thử từ khác hoặc chụp ảnh lá để AI nhận biết bệnh.'
                  : 'Cửa hàng chưa có danh sách vấn đề.',
              fallbackIcon: Icons.search_off_rounded,
            ),
          )
        else
          for (final p in items) _ProblemTile(problem: p),
      ],
    );
  }
}

/// Chưa biết bệnh gì: sang chụp ảnh lá (AI nhận biết rồi nối sang tư vấn).
class _PhotoShortcut extends StatelessWidget {
  const _PhotoShortcut();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primaryLight,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: const Key('advisory_photo_shortcut'),
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.go(AppRoutes.aiScan),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const Icon(Icons.photo_camera_outlined, color: AppColors.primaryDark),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Chưa biết lúa bị gì?',
                        style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700, color: AppColors.primaryDark)),
                    Text('Chụp ảnh lá bệnh để AI nhận biết rồi gợi ý thuốc.',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryDark)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.primaryDark),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProblemTile extends StatelessWidget {
  const _ProblemTile({required this.problem});

  final AdvisoryProblem problem;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          key: Key('advisory_problem_${problem.code}'),
          borderRadius: BorderRadius.circular(18),
          onTap: () => context.push('${AppRoutes.advisory}/problem/${problem.id}'),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(problem.displayName, style: AppTextStyles.h4),
                          StatusChip(
                            text: ProblemType.label(problem.problemType),
                            fg: AppColors.primaryDark,
                            bg: AppColors.primaryLight,
                          ),
                        ],
                      ),
                      if (problem.summary != null && problem.summary!.trim().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(problem.summary!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                      ],
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(left: 8, top: 2),
                  child: Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
