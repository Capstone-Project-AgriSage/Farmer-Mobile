import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../router/app_router.dart';

/// Onboarding — 3 slides, bám sát nội dung dự án AgriSage
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  static const _slides = [
    _OnboardingSlide(
      icon: Icons.shopping_bag_outlined,
      color: Color(0xFFE8F5E9),
      iconColor: AppColors.primary,
      title: 'Mua vật tư dễ dàng',
      description:
          'Đặt hàng phân bón, thuốc BVTV, hạt giống từ đại lý ngay trên điện thoại. Thanh toán qua QR hoặc ghi nợ mùa vụ.',
    ),
    _OnboardingSlide(
      icon: Icons.camera_alt_outlined,
      color: Color(0xFFF3E5F5),
      iconColor: Color(0xFF7B1FA2),
      title: 'AI chẩn đoán bệnh lúa',
      description:
          'Chụp ảnh lá lúa — AI nhận diện 4 bệnh phổ biến (Đạo ôn, Bạc lá, Khô vằn, Đốm nâu) và gợi ý thuốc phù hợp.',
    ),
    _OnboardingSlide(
      icon: Icons.account_balance_wallet_outlined,
      color: Color(0xFFFFF3E0),
      iconColor: Color(0xFFE65100),
      title: 'Sổ nợ minh bạch',
      description:
          'Theo dõi công nợ với đại lý. Xác nhận 2 chiều — tránh tranh chấp, mọi giao dịch đều có chứng từ rõ ràng.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: () => context.go(AppRoutes.welcome),
                child: Text(
                  'Bỏ qua',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),

            // Page view
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemCount: _slides.length,
                itemBuilder: (_, i) => _OnboardingPage(slide: _slides[i]),
              ),
            ),

            // Dots + buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Column(
                children: [
                  SmoothPageIndicator(
                    controller: _pageController,
                    count: _slides.length,
                    effect: WormEffect(
                      activeDotColor: AppColors.primary,
                      dotColor: AppColors.borderSubtle,
                      dotHeight: 8,
                      dotWidth: 8,
                    ),
                  ),
                  const SizedBox(height: 32),
                  if (_currentPage < _slides.length - 1)
                    ElevatedButton(
                      onPressed: () => _pageController.nextPage(
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeInOut,
                      ),
                      child: const Text('Tiếp theo'),
                    )
                  else
                    ElevatedButton(
                      onPressed: () => context.go(AppRoutes.welcome),
                      child: const Text('Bắt đầu ngay'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingSlide {
  final IconData icon;
  final Color color;
  final Color iconColor;
  final String title;
  final String description;
  const _OnboardingSlide({
    required this.icon,
    required this.color,
    required this.iconColor,
    required this.title,
    required this.description,
  });
}

class _OnboardingPage extends StatelessWidget {
  final _OnboardingSlide slide;
  const _OnboardingPage({required this.slide});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              color: slide.color,
              shape: BoxShape.circle,
            ),
            child: Icon(slide.icon, size: 80, color: slide.iconColor),
          ),
          const SizedBox(height: 40),
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: AppTextStyles.h2,
          ),
          const SizedBox(height: 16),
          Text(
            slide.description,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }
}
