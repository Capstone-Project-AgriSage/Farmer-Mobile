import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Nút Back của hệ thống trên màn có thể được mở bằng `context.go` (sau khi đặt hàng,
/// từ thông báo...): khi phía dưới không còn màn nào thì về [fallback] thay vì thoát app.
/// Nút ← trên thanh tiêu đề của các màn này đã làm như vậy; widget này làm cho nút Back
/// của Android giống hệt.
class FallbackPopScope extends StatelessWidget {
  const FallbackPopScope({super.key, required this.fallback, required this.child});

  /// Đường dẫn để về khi không thể quay lại.
  final String fallback;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final canPop = GoRouter.of(context).canPop();
    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(fallback);
      },
      child: child,
    );
  }
}
