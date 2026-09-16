import '../models/notification.dart';

final List<AppNotification> mockNotifications = [
  AppNotification(
    id: 'NOTIF-001',
    title: 'Đơn hàng đang được giao',
    body: 'Đơn hàng DH-20230928-B2 của bạn đang trên đường giao đến ấp 3, Xã Bình Thành. Vui lòng chú ý điện thoại.',
    createdAt: DateTime.now().subtract(const Duration(minutes: 45)),
    type: NotificationType.order,
    isRead: false,
    route: '/orders/ORD-1002',
  ),
  AppNotification(
    id: 'NOTIF-002',
    title: 'Nhắc nhở công nợ sắp đến hạn',
    body: 'Khoản nợ 15.000.000đ tại Đại lý VTNN Hai Lúa sẽ đến hạn trong 5 ngày tới. Vui lòng sắp xếp thanh toán.',
    createdAt: DateTime.now().subtract(const Duration(hours: 3)),
    type: NotificationType.debt,
    isRead: false,
    route: '/debt/D-001',
  ),
  AppNotification(
    id: 'NOTIF-003',
    title: 'Đơn hàng đã xác nhận',
    body: 'Đại lý đã xác nhận đơn hàng DH-20231001-A1 của bạn. Quá trình giao hàng sẽ sớm bắt đầu.',
    createdAt: DateTime.now().subtract(const Duration(hours: 12)),
    type: NotificationType.order,
    isRead: true,
    route: '/orders/ORD-1001',
  ),
  AppNotification(
    id: 'NOTIF-004',
    title: 'Khuyến mãi phân bón mùa vụ',
    body: 'Giảm 10% khi mua phân bón NPK 20-20-15 từ nay đến hết tháng. Nhanh tay đặt hàng qua ứng dụng!',
    createdAt: DateTime.now().subtract(const Duration(days: 2)),
    type: NotificationType.promotion,
    isRead: true,
    route: '/products',
  ),
  AppNotification(
    id: 'NOTIF-005',
    title: 'Cập nhật hệ thống AgriSage',
    body: 'Tính năng Khám cây AI đã được nâng cấp, tăng độ chính xác lên 95%. Hãy thử ngay!',
    createdAt: DateTime.now().subtract(const Duration(days: 5)),
    type: NotificationType.system,
    isRead: true,
    route: '/ai-scan',
  ),
];
