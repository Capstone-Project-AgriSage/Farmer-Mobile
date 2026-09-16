enum NotificationType { order, debt, system, promotion }

class AppNotification {
  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final NotificationType type;
  final bool isRead;
  final String? route; // Route path to navigate to when tapped

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.type,
    this.isRead = false,
    this.route,
  });
}
