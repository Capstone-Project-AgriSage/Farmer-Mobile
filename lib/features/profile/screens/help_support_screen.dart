import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

/// Trợ giúp: hướng dẫn dùng các chức năng có thật của ứng dụng. Chưa có kênh hỗ
/// trợ trong app (không có số tổng đài hay form phản hồi), nên hướng dẫn liên hệ
/// trực tiếp cửa hàng.
class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  static const faq = <(String, String)>[
    (
      'Làm sao để thanh toán công nợ?',
      'Vào tab Công nợ, bấm "Trả nợ", nhập số tiền rồi quét mã VietQR bằng app ngân hàng. '
          'Tiền luôn được trừ vào khoản đến hạn sớm nhất trước. Bạn cũng có thể trả trực tiếp tại cửa hàng.',
    ),
    (
      'Khi nào tôi mua ghi nợ được?',
      'Khi cửa hàng đã cấp hạn mức tín dụng cho bạn. Hạn mức và số nợ hiện tại xem ở tab Công nợ. '
          'Nếu chưa có hạn mức, hãy liên hệ cửa hàng.',
    ),
    (
      'Tôi có thể huỷ đơn hàng không?',
      'Bạn tự huỷ được khi đơn đang "Chờ xác nhận". Sau khi cửa hàng xác nhận, hãy liên hệ cửa hàng. '
          'Nếu bạn đã thanh toán, cửa hàng sẽ hoàn tiền cho bạn.',
    ),
    (
      'Làm sao để trả hàng?',
      'Mở đơn hàng đã nhận, chọn "Yêu cầu trả hàng", chọn hàng, số lượng và lý do. Cửa hàng sẽ duyệt; '
          'sau đó bạn mang hàng về cửa hàng để được kiểm tra. Tiền hoàn lại được trừ vào công nợ trước, phần còn lại hoàn bằng tiền.',
    ),
    (
      'Chẩn đoán bệnh lúa hoạt động thế nào?',
      'Bạn gửi ảnh lá lúa, chuyên gia của cửa hàng xem ảnh rồi gửi kết luận cùng hướng dẫn điều trị và sản phẩm gợi ý. '
          'Kết quả không hiện ngay: theo dõi trong "Lịch sử khám cây". Kết luận chỉ mang tính tham khảo, '
          'hãy hỏi thêm cửa hàng trước khi dùng thuốc.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppBar(title: const Text('Trợ giúp & Hỗ trợ')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Column(
                children: [
                  const Icon(Icons.storefront_outlined, size: 48, color: AppColors.primary),
                  const SizedBox(height: 16),
                  Text('Cần hỗ trợ trực tiếp?', style: AppTextStyles.h3, textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text(
                    'Hãy liên hệ cửa hàng nơi bạn mua vật tư. Cửa hàng xử lý đơn hàng, công nợ, trả hàng và giải đáp thắc mắc của bạn.',
                    key: const Key('help_contact'),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary, height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 12),
              child: Text('CÂU HỎI THƯỜNG GẶP',
                  style: AppTextStyles.caption
                      .copyWith(fontWeight: FontWeight.bold, color: AppColors.textMuted)),
            ),
            for (final (q, a) in faq) _buildFaqItem(q, a),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildFaqItem(String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: ExpansionTile(
        title: Text(question, style: AppTextStyles.labelLarge),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        shape: const Border(),
        collapsedShape: const Border(),
        children: [
          const Divider(height: 1, color: AppColors.borderSubtle),
          const SizedBox(height: 12),
          Text(answer,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary, height: 1.5)),
        ],
      ),
    );
  }
}
