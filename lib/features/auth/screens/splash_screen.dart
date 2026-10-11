import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../router/app_router.dart';
import '../providers/auth_controller.dart';

/// Splash — hiện logo, khôi phục phiên đăng nhập rồi điều hướng:
/// đã đăng nhập → Home (do router guard), chưa → Onboarding.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  bool _offline = false;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _scaleAnim = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _controller.forward();
    _start();
  }

  Future<void> _start() async {
    setState(() {
      _checking = true;
      _offline = false;
    });
    // Chạy song song: logo hiện tối thiểu 1.5s, trong lúc đó khôi phục phiên.
    final results = await Future.wait([
      ref.read(authControllerProvider).bootstrap(),
      Future<void>.delayed(const Duration(milliseconds: 1500)),
    ]);
    if (!mounted) return;
    switch (results.first as BootstrapResult) {
      case BootstrapResult.authenticated:
        // Router guard đã chuyển sang Home khi phiên được thiết lập.
        break;
      case BootstrapResult.unauthenticated:
        context.go(AppRoutes.onboarding);
      case BootstrapResult.offline:
        setState(() {
          _offline = true;
          _checking = false;
        });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: ScaleTransition(
            scale: _scaleAnim,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(
                    Icons.eco,
                    size: 56,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'AgriSage',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Hệ sinh thái nông nghiệp số',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 32),
                if (_checking)
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                if (_offline) ...[
                  const Text(
                    'Không kết nối được máy chủ',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _start,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primary,
                    ),
                    child: const Text('Thử lại'),
                  ),
                  TextButton(
                    onPressed: () async {
                      // Bỏ phiên đã lưu và đăng nhập lại.
                      final router = GoRouter.of(context);
                      await ref.read(authControllerProvider).logout();
                      router.go(AppRoutes.welcome);
                    },
                    child: const Text(
                      'Đăng nhập lại',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
