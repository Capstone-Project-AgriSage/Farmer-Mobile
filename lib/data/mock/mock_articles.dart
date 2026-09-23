import '../models/article.dart';

final List<Article> mockArticles = [
  Article(
    id: 'a1',
    title: 'Cách phòng trừ bệnh đạo ôn lúa Đông Xuân',
    snippet: 'Bệnh đạo ôn là một trong những bệnh nguy hiểm nhất trên lúa, đặc biệt trong vụ Đông Xuân. Tìm hiểu cách phòng trị hiệu quả.',
    content: 'Bệnh đạo ôn do nấm Pyricularia oryzae gây ra, có thể gây hại ở tất cả các giai đoạn phát triển của cây lúa, từ giai đoạn mạ đến khi trổ bông...\n\nCác biện pháp phòng trừ:\n1. Chọn giống lúa kháng bệnh.\n2. Bón phân cân đối, tránh bón thừa đạm.\n3. Vệ sinh đồng ruộng, diệt cỏ dại.\n4. Sử dụng thuốc bảo vệ thực vật khi cần thiết theo nguyên tắc 4 đúng.',
    imageUrl: 'https://images.unsplash.com/photo-1595186259024-2c672b146430?q=80&w=2938&auto=format&fit=crop',
    category: 'Sâu Bệnh',
    author: 'Kỹ sư Nông nghiệp AgriSage',
    publishedAt: DateTime.now().subtract(const Duration(days: 2)),
    viewCount: 1250,
  ),
  Article(
    id: 'a2',
    title: 'Kỹ thuật bón phân đón đòng tăng năng suất',
    snippet: 'Bón phân đón đòng đúng thời điểm và liều lượng giúp lúa trổ đều, bông to, hạt chắc.',
    content: 'Giai đoạn đón đòng là lúc cây lúa cần nhiều dinh dưỡng nhất để hình thành bông. Việc bón phân đúng cách sẽ quyết định trực tiếp đến năng suất lúa...\n\nThời điểm bón:\nNên bón phân khi lúa có biểu hiện tròn mình (khoảng 40-45 ngày sau sạ đối với giống ngắn ngày).',
    imageUrl: 'https://images.unsplash.com/photo-1523348837708-15d4a09cfac2?q=80&w=2940&auto=format&fit=crop',
    category: 'Kỹ Thuật',
    author: 'Viện Lúa ĐBSCL',
    publishedAt: DateTime.now().subtract(const Duration(days: 5)),
    viewCount: 842,
  ),
  Article(
    id: 'a3',
    title: 'Cập nhật giá lúa gạo thị trường ĐBSCL tuần này',
    snippet: 'Giá lúa Hè Thu tại các tỉnh ĐBSCL đang có xu hướng tăng nhẹ so với tuần trước do nhu cầu xuất khẩu tăng.',
    content: 'Theo ghi nhận tại các tỉnh Đồng bằng sông Cửu Long, giá lúa gạo hôm nay có xu hướng tăng nhẹ từ 100 - 200 đồng/kg so với cuối tuần trước...\n\nCụ thể:\n- Lúa IR 50404: 7.200 - 7.400 đ/kg\n- Lúa OM 5451: 7.500 - 7.700 đ/kg\n- Lúa Đài thơm 8: 7.800 - 8.000 đ/kg',
    imageUrl: 'https://images.unsplash.com/photo-1586201375761-83865001e8ac?q=80&w=2940&auto=format&fit=crop',
    category: 'Thị Trường',
    author: 'Tổng cục Thống kê',
    publishedAt: DateTime.now().subtract(const Duration(hours: 12)),
    viewCount: 3200,
  ),
];
