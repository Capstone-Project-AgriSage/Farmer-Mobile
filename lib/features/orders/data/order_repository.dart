import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/json_utils.dart';
import '../../../core/network/paged_result.dart';
import 'order_models.dart';

Future<T> _run<T>(Future<T> Function() call,
    {Map<int, String> messages = const {},
    ApiException Function(ApiException e)? map}) async {
  try {
    return await call();
  } on DioException catch (e) {
    final error = ApiException.from(e);
    final mapped = map?.call(error) ?? error;
    final override = messages[mapped.statusCode];
    throw override == null || mapped != error ? mapped : error.withMessage(override);
  }
}

/// Đổi lý do từ chối khi đặt hàng (backend trả tiếng Anh) sang tiếng Việt.
/// Backend không có mã lỗi riêng nên phải dựa vào nội dung `detail`.
ApiException mapCheckoutError(ApiException e) {
  if (e.statusCode == 422) {
    final d = e.detail ?? '';
    String? msg;
    if (d.contains('OVERDUE_DEBT')) {
      msg = 'Bạn đang có khoản nợ quá hạn. Vui lòng thanh toán nợ trước khi mua ghi nợ.';
    } else if (d.contains('INSUFFICIENT_CREDIT')) {
      msg = 'Hạn mức mua ghi nợ còn lại không đủ cho đơn này.';
    } else if (d.contains('CREDIT_DISABLED') ||
        d.contains('NO_CREDIT_LIMIT') ||
        d.contains('NO_CREDIT_TERM')) {
      msg = 'Bạn chưa được cửa hàng cấp hạn mức mua ghi nợ.';
    } else if (d.contains('Credit refused')) {
      msg = 'Không thể mua ghi nợ cho đơn này.';
    } else if (d.contains('stock')) {
      msg = 'Cửa hàng không đủ hàng cho đơn mua ghi nợ này. Vui lòng giảm số lượng hoặc chọn trả ngay.';
    } else if (d.contains('cart is empty')) {
      msg = 'Giỏ hàng đang trống.';
    } else if (d.contains('at most')) {
      msg = 'Đơn hàng có quá nhiều sản phẩm. Vui lòng tách thành nhiều đơn.';
    } else if (e.fieldErrors.keys.any((k) => k.startsWith('items'))) {
      msg = 'Có sản phẩm trong giỏ không còn đặt được. Vui lòng kiểm tra lại giỏ hàng.';
    } else if (d.toLowerCase().contains('address')) {
      msg = 'Địa chỉ giao hàng không hợp lệ hoặc đã bị xoá. Vui lòng chọn lại.';
    }
    if (msg != null) return e.withMessage(msg);
  }
  if (e.statusCode == 404) {
    return e.withMessage('Địa chỉ giao hàng không còn tồn tại. Vui lòng chọn lại.');
  }
  return e;
}

/// Đơn hàng của nông dân (`/api/me/orders`).
class OrderRepository {
  OrderRepository(this._dio);

  final Dio _dio;

  static const pageSize = 20;
  static const maxNoteLength = 1000;

  /// Đặt hàng từ giỏ hiện tại. [addressId] bắt buộc khi giao hàng.
  Future<OrderDetail> checkout({
    required String settlementType,
    required String fulfillmentType,
    String? addressId,
    String? note,
  }) =>
      _run(
        () async {
          final trimmed = note?.trim();
          final res = await _dio.post<Map<String, dynamic>>(
            '/api/me/orders',
            data: {
              'source': AppConfig.orderSource,
              'settlementType': settlementType,
              'fulfillmentType': fulfillmentType,
              if (fulfillmentType == FulfillmentType.delivery)
                'addressId': addressId,
              if (trimmed != null && trimmed.isNotEmpty) 'note': trimmed,
            },
          );
          return OrderDetail.fromJson(res.data!);
        },
        map: mapCheckoutError,
      );

  Future<PagedResult<OrderSummary>> list({int page = 1, String? status}) =>
      _run(() async {
        final res = await _dio.get<Map<String, dynamic>>(
          '/api/me/orders',
          queryParameters:
              cleanQuery({'page': page, 'pageSize': pageSize, 'status': status}),
        );
        return PagedResult.fromJson(res.data!, OrderSummary.fromJson);
      });

  Future<OrderDetail> get(String id) => _run(
        () async {
          final res = await _dio.get<Map<String, dynamic>>('/api/me/orders/$id');
          return OrderDetail.fromJson(res.data!);
        },
        messages: {404: 'Không tìm thấy đơn hàng.'},
      );

  /// Chỉ huỷ được khi đơn đang chờ xác nhận.
  Future<OrderDetail> cancel(String id, {String? reason}) => _run(
        () async {
          final r = reason?.trim();
          final res = await _dio.post<Map<String, dynamic>>(
            '/api/me/orders/$id/cancel',
            data: {if (r != null && r.isNotEmpty) 'reason': r},
          );
          return OrderDetail.fromJson(res.data!);
        },
        messages: {
          422: 'Cửa hàng đã xác nhận đơn nên không thể huỷ online. Vui lòng liên hệ cửa hàng.',
          404: 'Không tìm thấy đơn hàng.',
        },
      );

  Future<List<Delivery>> deliveries(String orderId) => _run(() async {
        final res =
            await _dio.get<List<dynamic>>('/api/me/orders/$orderId/deliveries');
        return [
          for (final d in res.data!) Delivery.fromJson(d as Map<String, dynamic>),
        ];
      });

  Future<OrderPayments> payments(String orderId) => _run(() async {
        final res = await _dio
            .get<Map<String, dynamic>>('/api/me/orders/$orderId/payments');
        return OrderPayments.fromJson(res.data!);
      });
}

/// Thanh toán payOS của nông dân.
class PaymentRepository {
  PaymentRepository(this._dio);

  final Dio _dio;

  static const _unavailable =
      'Thanh toán online đang gián đoạn. Vui lòng thử lại sau hoặc thanh toán tại cửa hàng.';

  /// Tạo link payOS trả phần còn lại của đơn. Server tự huỷ link cũ đang chờ.
  Future<PayOsLink> createForOrder(String orderId) => _run(
        () async {
          final res = await _dio.post<Map<String, dynamic>>(
            '/api/me/payments/payos',
            data: {'paymentContext': 'ORDER_PAYMENT', 'orderId': orderId},
          );
          return PayOsLink.fromJson(res.data!);
        },
        messages: {
          503: _unavailable,
          409: 'Đơn hàng vừa được thanh toán. Đang tải lại thông tin đơn.',
        },
        map: (e) {
          final d = e.detail ?? '';
          if (e.statusCode == 422 && d.contains('nothing left to pay')) {
            return e.withMessage('Đơn hàng đã được thanh toán đủ.');
          }
          if (e.statusCode == 422 && d.contains('cannot take a payment')) {
            return e.withMessage('Đơn hàng đã huỷ hoặc đã hoàn thành, không cần thanh toán.');
          }
          return e;
        },
      );

  /// Trạng thái thật của khoản thanh toán (chỉ tin cái này, không tin returnUrl).
  Future<Payment> get(String paymentId) => _run(() async {
        final res =
            await _dio.get<Map<String, dynamic>>('/api/me/payments/$paymentId');
        return Payment.fromJson(res.data!);
      });

  /// Hỏi payOS trực tiếp khi webhook chậm.
  Future<Payment> sync(String paymentId) => _run(
        () async {
          final res = await _dio
              .post<Map<String, dynamic>>('/api/payments/$paymentId/sync');
          return Payment.fromJson(res.data!);
        },
        messages: {503: _unavailable},
      );

  Future<Payment> cancel(String paymentId) => _run(
        () async {
          final res = await _dio.post<Map<String, dynamic>>(
              '/api/me/payments/$paymentId/cancel');
          return Payment.fromJson(res.data!);
        },
        messages: {
          422: 'Khoản thanh toán này không còn ở trạng thái chờ.',
          503: _unavailable,
        },
      );

  /// CHỈ môi trường dev (PayOS:Mode=Simulated): giả lập đã trả tiền.
  /// Môi trường thật trả 404.
  Future<Payment> simulatePaid(String paymentId) => _run(
        () async {
          final res = await _dio.post<Map<String, dynamic>>(
              '/api/payments/$paymentId/simulate-paid');
          return Payment.fromJson(res.data!);
        },
        messages: {404: 'Máy chủ không bật chế độ giả lập thanh toán.'},
      );
}

/// Hạn mức mua ghi nợ (`GET /api/me/credit`). null = chưa được cấp.
class CreditRepository {
  CreditRepository(this._dio);

  final Dio _dio;

  Future<CreditSummary?> mine() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/api/me/credit');
      return CreditSummary.fromJson(res.data!);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw ApiException.from(e);
    }
  }
}

final orderRepositoryProvider =
    Provider<OrderRepository>((ref) => OrderRepository(ref.watch(dioProvider)));
final paymentRepositoryProvider = Provider<PaymentRepository>(
    (ref) => PaymentRepository(ref.watch(dioProvider)));
final creditRepositoryProvider =
    Provider<CreditRepository>((ref) => CreditRepository(ref.watch(dioProvider)));
