import 'status_label.dart';

// Order, payment and delivery are three separate states (FE_GUIDE_FLOW_2 §2); these are the words the farmer sees.
// Copied from Farmer-Web `orderLabels.ts`.

const orderStatusLabels = <String, StatusLabel>{
  'PENDING_CONFIRMATION': StatusLabel('Chờ xác nhận', LabelTone.pending),
  'CONFIRMED': StatusLabel('Đã xác nhận', LabelTone.progress),
  'PREPARING': StatusLabel('Đang chuẩn bị', LabelTone.progress),
  'READY_FOR_FULFILLMENT': StatusLabel('Sẵn sàng giao', LabelTone.progress),
  'PARTIALLY_FULFILLED': StatusLabel('Đã giao một phần', LabelTone.progress),
  'COMPLETED': StatusLabel('Hoàn thành', LabelTone.success),
  'CANCELLED': StatusLabel('Đã hủy', LabelTone.danger),
  'PARTIALLY_CANCELLED': StatusLabel('Hủy phần còn lại', LabelTone.danger),
};

const deliveryStatusLabels = <String, StatusLabel>{
  'DRAFT': StatusLabel('Nháp', LabelTone.neutral),
  'ASSIGNED': StatusLabel('Đã phân công', LabelTone.pending),
  'OUT_FOR_DELIVERY': StatusLabel('Đang giao', LabelTone.progress),
  'PARTIALLY_DELIVERED': StatusLabel('Đã giao một phần', LabelTone.progress),
  'RETRY_PENDING': StatusLabel('Chờ giao lại', LabelTone.pending),
  'DELIVERED': StatusLabel('Đã giao', LabelTone.success),
  'CANCELLED': StatusLabel('Đã hủy', LabelTone.danger),
};

const attemptStatusLabels = <String, StatusLabel>{
  'IN_PROGRESS': StatusLabel('Đang giao', LabelTone.progress),
  'SUCCESS': StatusLabel('Thành công', LabelTone.success),
  'PARTIAL_SUCCESS': StatusLabel('Giao một phần', LabelTone.pending),
  'FAILED': StatusLabel('Không thành công', LabelTone.danger),
  'CANCELLED': StatusLabel('Đã hủy', LabelTone.neutral),
};

const paymentStatusLabels = <String, StatusLabel>{
  'PENDING': StatusLabel('Chờ thanh toán', LabelTone.pending),
  'PAID': StatusLabel('Đã thanh toán', LabelTone.success),
  'FAILED': StatusLabel('Thất bại / hết hạn', LabelTone.danger),
  'CANCELLED': StatusLabel('Đã hủy', LabelTone.neutral),
  'PARTIALLY_REFUNDED': StatusLabel('Hoàn tiền một phần', LabelTone.neutral),
  'REFUNDED': StatusLabel('Đã hoàn tiền', LabelTone.neutral),
};

const failureReasonLabels = <String, String>{
  'CUSTOMER_ABSENT': 'Khách vắng nhà',
  'UNREACHABLE': 'Không liên lạc được',
  'CUSTOMER_REFUSED': 'Khách từ chối nhận',
  'DAMAGED': 'Hàng hư hỏng',
  'WEATHER': 'Thời tiết',
  'VEHICLE_ISSUE': 'Sự cố xe',
  'ADDRESS_ISSUE': 'Sai / khó tìm địa chỉ',
  'OTHER': 'Khác',
};

String failureReasonLabel(String? code) => code == null ? '' : (failureReasonLabels[code] ?? code);

const paymentMethodLabels = <String, String>{
  'PAYOS': 'payOS (VietQR)',
  'CASH': 'Tiền mặt',
  'BANK_TRANSFER': 'Chuyển khoản',
};

String paymentMethodLabel(String? code) => code == null ? '' : (paymentMethodLabels[code] ?? code);

String settlementLabel(String code) => switch (code) {
      'CREDIT' => 'Mua ghi nợ',
      'FULL_PAYMENT' => 'Thanh toán đủ',
      _ => code,
    };
