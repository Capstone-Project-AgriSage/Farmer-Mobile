/// "Vừa xong", "5 phút trước", "3 giờ trước", "2 ngày trước", hoặc ngày đầy đủ
/// (dd/MM/yyyy) sau 7 ngày. [now] chỉ để test.
String formatTimeAgo(DateTime dt, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(dt);
  if (diff.isNegative || diff.inMinutes < 1) return 'Vừa xong';
  if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
  if (diff.inHours < 24) return '${diff.inHours} giờ trước';
  if (diff.inDays < 7) return '${diff.inDays} ngày trước';
  final l = dt.toLocal();
  return '${l.day.toString().padLeft(2, '0')}/${l.month.toString().padLeft(2, '0')}/${l.year}';
}
