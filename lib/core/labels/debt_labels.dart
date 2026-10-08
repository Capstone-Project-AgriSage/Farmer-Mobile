import 'status_label.dart';

// Wording follows what the store does with an entry (FLOW_3 §6): a dispute is reviewed, then the amount is kept,
// adjusted or cancelled. Copied from Farmer-Web `debtLabels.ts`.

const debtEntryStatusLabels = <String, StatusLabel>{
  'OPEN': StatusLabel('Chưa trả', LabelTone.pending),
  'PARTIALLY_PAID': StatusLabel('Đã trả một phần', LabelTone.progress),
  'PAID': StatusLabel('Đã tất toán', LabelTone.success),
  'DISPUTED': StatusLabel('Đang khiếu nại', LabelTone.danger),
  'ADJUSTED': StatusLabel('Đã điều chỉnh', LabelTone.neutral),
  'CANCELLED': StatusLabel('Đã hủy', LabelTone.neutral),
};

/// The filter chips on the debt screen: `null` is every entry.
const debtEntryFilters = <(String label, String? status)>[
  ('Tất cả', null),
  ('Chưa trả', 'OPEN'),
  ('Trả một phần', 'PARTIALLY_PAID'),
  ('Khiếu nại', 'DISPUTED'),
  ('Đã tất toán', 'PAID'),
];

/// An entry the farmer may still dispute: not closed (paid or cancelled) and not already disputed.
bool canDisputeDebtEntry(String status) => status == 'OPEN' || status == 'PARTIALLY_PAID' || status == 'ADJUSTED';

const debtSourceLabels = <String, String>{
  'DELIVERY': 'Mua chịu, giao hàng',
  'PICKUP': 'Mua chịu, lấy tại quầy',
  'MANUAL_ADJUSTMENT': 'Ghi nợ thủ công',
};

String debtSourceLabel(String code) => debtSourceLabels[code] ?? code;

const debtTransactionLabels = <String, String>{
  'CREDIT_SALE': 'Ghi nợ từ đơn hàng',
  'PAYMENT': 'Trả nợ',
  'ADJUSTMENT_IN': 'Điều chỉnh tăng nợ',
  'ADJUSTMENT_OUT': 'Điều chỉnh giảm nợ',
  'RETURN': 'Trả hàng, giảm nợ',
  'REVERSAL': 'Hoàn tác',
};

String debtTransactionLabel(String code) => debtTransactionLabels[code] ?? code;

const debtActionLabels = <String, String>{
  'DISPUTE': 'Bác đã khiếu nại',
  'KEEP': 'Cửa hàng giữ nguyên số nợ',
  'ADJUST': 'Cửa hàng điều chỉnh số nợ',
  'CANCEL': 'Cửa hàng hủy khoản nợ',
  'CHANGE_DUE_DATE': 'Cửa hàng đổi hạn trả',
};

String debtActionLabel(String code) => debtActionLabels[code] ?? code;

const repaymentStatusLabels = <String, StatusLabel>{
  'PENDING': StatusLabel('Đang chờ thanh toán', LabelTone.pending),
  'PAID': StatusLabel('Đã thanh toán', LabelTone.success),
  'FAILED': StatusLabel('Không thành công', LabelTone.danger),
  'CANCELLED': StatusLabel('Đã hủy', LabelTone.neutral),
  'PARTIALLY_REFUNDED': StatusLabel('Đã hoàn một phần', LabelTone.neutral),
  'REFUNDED': StatusLabel('Đã hoàn tiền', LabelTone.neutral),
};

const repaymentMethodLabels = <String, String>{
  'PAYOS': 'Chuyển khoản qua payOS',
  'CASH': 'Tiền mặt tại quầy',
  'BANK_TRANSFER': 'Chuyển khoản ngân hàng',
};

String repaymentMethodLabel(String code) => repaymentMethodLabels[code] ?? code;
