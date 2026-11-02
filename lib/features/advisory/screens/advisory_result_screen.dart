import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/network/api_exception.dart';
import '../../../router/app_router.dart';
import '../../../shared/widgets/error_retry_widget.dart';
import '../../ai_doctor/data/diagnosis_models.dart' show Treatment, treatmentTypeLabel;
import '../../orders/widgets/order_widgets.dart' show SectionCard, StatusChip;
import '../../products/providers/catalog_providers.dart';
import '../../products/widgets/product_widgets.dart' show CartIconButton;
import '../data/advisory_models.dart';
import '../data/advisory_repository.dart';
import '../providers/advisory_providers.dart';
import '../widgets/advisory_product_card.dart';

/// Sản phẩm gợi ý cho một vấn đề: nhập diện tích và giai đoạn lúa để biết cần bao nhiêu, thêm vào giỏ bằng một lần
/// bấm. Danh sách chỉ gồm sản phẩm cửa hàng đã duyệt; giá, số lượng, tình trạng hàng do server tính.
class AdvisoryResultScreen extends ConsumerStatefulWidget {
  const AdvisoryResultScreen({super.key, required this.diseaseId, this.diagnosisCaseId});

  final String diseaseId;

  /// Có khi nông dân đi từ kết quả chẩn đoán AI sang.
  final String? diagnosisCaseId;

  @override
  ConsumerState<AdvisoryResultScreen> createState() => _AdvisoryResultScreenState();
}

class _AdvisoryResultScreenState extends ConsumerState<AdvisoryResultScreen> {
  final _areaCtrl = TextEditingController();
  AreaUnit _unit = AreaUnit.cong;
  String? _stage;
  String? _areaError;
  late AdvisoryQuery _query;
  String? _addingId;

  @override
  void initState() {
    super.initState();
    // Diện tích lần trước nằm sẵn trong ô, và dùng ngay cho lần tư vấn đầu (không gọi hai lần).
    final remembered = ref.read(advisoryAreaProvider);
    double? sqm;
    if (remembered != null && remembered.sqm <= AdvisoryRepository.maxAreaSqm) {
      _areaCtrl.text = remembered.valueText;
      _unit = remembered.unit;
      sqm = remembered.sqm;
    }
    _query = AdvisoryQuery(diseaseId: widget.diseaseId, areaSqm: sqm, diagnosisCaseId: widget.diagnosisCaseId);
  }

  @override
  void dispose() {
    _areaCtrl.dispose();
    super.dispose();
  }

  /// Đọc ô diện tích: rỗng = chưa nhập (hợp lệ); khác thì phải là số lớn hơn 0 và không vượt giới hạn của server.
  ({bool ok, double? value}) _parseArea() {
    final text = _areaCtrl.text.trim().replaceAll(',', '.');
    if (text.isEmpty) return (ok: true, value: null);
    final v = double.tryParse(text);
    if (v == null || v <= 0 || v * _unit.sqm > AdvisoryRepository.maxAreaSqm) return (ok: false, value: null);
    return (ok: true, value: v);
  }

  void _apply() {
    FocusScope.of(context).unfocus();
    final parsed = _parseArea();
    if (!parsed.ok) {
      setState(() => _areaError = 'Nhập diện tích là số lớn hơn 0 (tối đa 1.000 ha).');
      return;
    }
    final value = parsed.value;
    ref.read(advisoryAreaProvider.notifier).save(value == null ? null : AreaInput(value, _unit));
    setState(() {
      _areaError = null;
      _query = AdvisoryQuery(
        diseaseId: widget.diseaseId,
        areaSqm: value == null ? null : value * _unit.sqm,
        growthStage: _stage,
        diagnosisCaseId: widget.diagnosisCaseId,
      );
    });
  }

  void _pickStage(String? stage) {
    _stage = stage;
    _apply();
  }

  Future<void> _addToCart(AdvisoryProduct p) async {
    final plan = p.plan;
    if (plan == null || _addingId != null) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _addingId = p.storeProductId);
    try {
      for (final line in plan.lines) {
        await ref.read(cartProvider.notifier).add(
              storeProductId: p.storeProductId,
              packagingId: line.packagingId,
              quantity: line.quantity,
            );
      }
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text('Đã thêm ${p.name} vào giỏ hàng.'),
          action: SnackBarAction(label: 'Xem giỏ', onPressed: () => context.push(AppRoutes.cart)),
        ));
    } on ApiException catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _addingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(advisoryRecommendationProvider(_query));

    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        title: Text('Tư vấn vật tư', style: AppTextStyles.h3),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(color: AppColors.surfaceSubtle, borderRadius: BorderRadius.circular(14)),
            child: const CartIconButton(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          result.when(
            loading: () => const SizedBox(height: 120, child: Center(child: CircularProgressIndicator())),
            error: (e, _) => SizedBox(
              height: 260,
              child: ErrorRetryWidget(error: e, onRetry: () => ref.invalidate(advisoryRecommendationProvider(_query))),
            ),
            data: (r) => _ProblemHeader(problem: r.problem, fromAi: widget.diagnosisCaseId != null),
          ),
          const SizedBox(height: 12),
          _FieldCard(
            controller: _areaCtrl,
            unit: _unit,
            stage: _stage,
            error: _areaError,
            onUnit: (u) => setState(() => _unit = u),
            onStage: _pickStage,
            onApply: _apply,
          ),
          const SizedBox(height: 12),
          if (result.hasValue) ..._sections(result.requireValue),
        ],
      ),
    );
  }

  List<Widget> _sections(AdvisoryRecommendation r) {
    final reason = emptyReasonText(r.emptyReason);
    final hasArea = r.areaSqm != null;
    Widget cards(String title, IconData icon, List<AdvisoryProduct> items, String key) => SectionCard(
          icon: icon,
          title: title,
          child: Column(
            key: Key(key),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final p in items)
                AdvisoryProductCard(
                  product: p,
                  hasArea: hasArea,
                  adding: _addingId == p.storeProductId,
                  onAdd: () => _addToCart(p),
                  onOpen: () => context.push('${AppRoutes.products}/${p.storeProductId}'),
                ),
            ],
          ),
        );

    return [
      if (r.careGuidance.isNotEmpty) ...[
        SectionCard(
          icon: Icons.agriculture_outlined,
          title: 'Cách chăm sóc',
          child: Column(
            key: const Key('advisory_care'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < r.careGuidance.length; i++) ...[
                if (i > 0) const Divider(height: 20, color: AppColors.borderSubtle),
                _CareTile(t: r.careGuidance[i]),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
      if (!r.hasProducts)
        SectionCard(
          icon: Icons.info_outline,
          title: 'Sản phẩm gợi ý',
          child: Text(reason ?? 'Chưa có sản phẩm gợi ý.',
              key: const Key('advisory_empty_reason'),
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
        ),
      if (r.protection.isNotEmpty) ...[
        cards('Thuốc bảo vệ thực vật', Icons.medical_services_outlined, r.protection, 'advisory_protection'),
        const SizedBox(height: 12),
      ],
      if (r.nutrition.isNotEmpty) ...[
        cards('Phân bón', Icons.grass_rounded, r.nutrition, 'advisory_nutrition'),
        const SizedBox(height: 12),
      ],
      Container(
        key: const Key('advisory_disclaimer'),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: const Color(0xFFFFF8E1), borderRadius: BorderRadius.circular(14)),
        child: Text(
          r.safetyNote.isNotEmpty
              ? r.safetyNote
              : 'Đọc kỹ nhãn trước khi dùng, mang đồ bảo hộ, tuân thủ thời gian cách ly. Gợi ý chỉ mang tính tham khảo.',
          style: AppTextStyles.caption.copyWith(color: const Color(0xFF5D4037), height: 1.4),
        ),
      ),
    ];
  }
}

class _ProblemHeader extends StatelessWidget {
  const _ProblemHeader({required this.problem, required this.fromAi});

  final AdvisoryProblemDetail problem;
  final bool fromAi;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('advisory_problem_header'),
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StatusChip(text: ProblemType.label(problem.problemType), fg: AppColors.primaryDark, bg: AppColors.surface),
              if (fromAi) const StatusChip(text: 'Từ kết quả AI', fg: AppColors.primaryDark, bg: AppColors.surface),
            ],
          ),
          const SizedBox(height: 8),
          Text(problem.displayName, key: const Key('advisory_problem_name'), style: AppTextStyles.h2.copyWith(color: AppColors.primaryDark)),
          if (problem.symptoms != null && problem.symptoms!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(problem.symptoms!, maxLines: 4, overflow: TextOverflow.ellipsis, style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryDark)),
          ],
        ],
      ),
    );
  }
}

/// Diện tích ruộng và giai đoạn lúa: hai điều kiện để tính số lượng và lọc sản phẩm.
class _FieldCard extends StatelessWidget {
  const _FieldCard({
    required this.controller,
    required this.unit,
    required this.stage,
    required this.error,
    required this.onUnit,
    required this.onStage,
    required this.onApply,
  });

  final TextEditingController controller;
  final AreaUnit unit;
  final String? stage;
  final String? error;
  final ValueChanged<AreaUnit> onUnit;
  final ValueChanged<String?> onStage;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      icon: Icons.crop_square_rounded,
      title: 'Ruộng của bạn',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Diện tích ruộng', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          TextField(
            key: const Key('advisory_area'),
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onApply(),
            maxLength: 12,
            decoration: InputDecoration(
              hintText: 'Ví dụ: 3',
              counterText: '',
              errorText: error,
              filled: true,
              fillColor: AppColors.surfaceSubtle,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final u in AreaUnit.values)
                ChoiceChip(
                  key: Key('advisory_unit_${u.name}'),
                  label: Text(u.label),
                  selected: unit == u,
                  showCheckmark: false,
                  selectedColor: AppColors.primaryLight,
                  onSelected: (_) => onUnit(u),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text('1 công = 1.000 m², 1 sào = 360 m².', style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
          const SizedBox(height: 14),
          Text('Lúa đang ở giai đoạn', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              ChoiceChip(
                key: const Key('advisory_stage_any'),
                label: const Text('Chưa rõ'),
                selected: stage == null,
                showCheckmark: false,
                selectedColor: AppColors.primaryLight,
                onSelected: (_) => onStage(null),
              ),
              for (final s in GrowthStage.values)
                ChoiceChip(
                  key: Key('advisory_stage_$s'),
                  label: Text(GrowthStage.label(s)),
                  selected: stage == s,
                  showCheckmark: false,
                  selectedColor: AppColors.primaryLight,
                  onSelected: (_) => onStage(s),
                ),
            ],
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            key: const Key('advisory_apply'),
            onPressed: onApply,
            style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)),
            child: const Text('Tính số lượng cần mua'),
          ),
        ],
      ),
    );
  }
}

class _CareTile extends StatelessWidget {
  const _CareTile({required this.t});

  final Treatment t;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            StatusChip(text: treatmentTypeLabel(t.type), fg: AppColors.primaryDark, bg: AppColors.primaryLight),
            Text(t.title, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 6),
        Text(t.instructions, style: AppTextStyles.bodySmall),
        if (t.precautions != null && t.precautions!.trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('Lưu ý: ${t.precautions}', style: AppTextStyles.caption.copyWith(color: AppColors.statusWarning)),
        ],
      ],
    );
  }
}
