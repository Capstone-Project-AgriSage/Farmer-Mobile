# 📱 AgriSage – Farmer Mobile App · Screen Checklist (v2 — Đúng phạm vi đề tài)

> **Dự án:** AgriSage – Ứng dụng hỗ trợ nông dân  
> **Nền tảng:** Flutter  
> **Cập nhật:** 2026-09-15 · Đã đối chiếu với Báo cáo Capstone  
> **Trạng thái:** `[ ]` Chưa làm · `[/]` Đang làm · `[x]` Hoàn thành

---

## 1. 🔐 Onboarding & Xác thực

| # | Màn hình | Widget / File gợi ý | Trạng thái |
|---|----------|---------------------|------------|
| 1.1 | Splash Screen (logo + loading) | `SplashScreen` | `[ ]` |
| 1.2 | Giới thiệu ứng dụng – Onboarding (3 slides) | `OnboardingScreen` | `[ ]` |
| 1.3 | Màn hình chào – Chọn Đăng nhập / Đăng ký | `WelcomeScreen` | `[ ]` |
| 1.4 | Đăng nhập (SĐT / Email + mật khẩu) | `LoginScreen` | `[ ]` |
| 1.5 | Đăng ký tài khoản nông dân | `RegisterScreen` | `[ ]` |
| 1.6 | Xác minh OTP (SĐT) | `OtpVerifyScreen` | `[ ]` |
| 1.7 | Quên mật khẩu | `ForgotPasswordScreen` | `[ ]` |
| 1.8 | Đặt lại mật khẩu | `ResetPasswordScreen` | `[ ]` |

---

## 2. 🏠 Trang chủ (Home Dashboard)

> Ưu tiên hiển thị: Đặt hàng nhanh · Scan AI · Xem công nợ · Thông báo

| # | Màn hình | Widget / File gợi ý | Trạng thái |
|---|----------|---------------------|------------|
| 2.1 | Dashboard tổng quan (shortcuts + thông báo mới) | `HomeScreen` | `[ ]` |
| 2.2 | Danh sách thông báo (xác nhận đơn, duyệt AI, nợ) | `NotificationScreen` | `[ ]` |

---

## 3. 🛒 Sản phẩm & Đặt hàng

> Luồng: Xem sản phẩm đại lý → Giỏ hàng → Xác nhận → Theo dõi đơn

| # | Màn hình | Widget / File gợi ý | Trạng thái |
|---|----------|---------------------|------------|
| 3.1 | Danh sách sản phẩm của đại lý | `ProductListScreen` | `[ ]` |
| 3.2 | Chi tiết sản phẩm (giá, mô tả, tồn kho) | `ProductDetailScreen` | `[ ]` |
| 3.3 | Giỏ hàng | `CartScreen` | `[ ]` |
| 3.4 | Xác nhận đơn hàng (chọn thanh toán QR / ghi nợ) | `OrderConfirmScreen` | `[ ]` |
| 3.5 | Danh sách đơn hàng của tôi | `OrderListScreen` | `[ ]` |
| 3.6 | Chi tiết đơn hàng (trạng thái giao hàng) | `OrderDetailScreen` | `[ ]` |

---

## 4. 💳 Thanh toán QR – VietQR

> Luồng: Hiển thị QR → Nông dân quét bằng app ngân hàng → Chờ đại lý xác nhận → Kết quả

| # | Màn hình | Widget / File gợi ý | Trạng thái |
|---|----------|---------------------|------------|
| 4.1 | Hiển thị mã QR VietQR tĩnh | `QrPaymentScreen` | `[ ]` |
| 4.2 | Chờ xác nhận thanh toán (pending — đại lý confirm) | `PaymentPendingScreen` | `[ ]` |
| 4.3 | Kết quả thanh toán (thành công / thất bại) | `PaymentResultScreen` | `[ ]` |

---

## 5. 📒 Sổ nợ điện tử (2 chiều)

> Tính năng đặc trưng: **Nông dân phải xác nhận khoản nợ** → tránh tranh chấp

| # | Màn hình | Widget / File gợi ý | Trạng thái |
|---|----------|---------------------|------------|
| 5.1 | Tổng quan công nợ với đại lý | `DebtOverviewScreen` | `[ ]` |
| 5.2 | Danh sách chi tiết các khoản nợ | `DebtListScreen` | `[ ]` |
| 5.3 | Chi tiết khoản nợ (ngày, số tiền, trạng thái) | `DebtDetailScreen` | `[ ]` |
| 5.4 | **Xác nhận khoản nợ** (nông dân ký xác nhận 2 chiều) | `DebtConfirmScreen` | `[ ]` |
| 5.5 | Lịch sử thanh toán nợ | `DebtHistoryScreen` | `[ ]` |

---

## 6. 🤖 AI Chẩn đoán bệnh lúa

> Phạm vi AI: 4 bệnh — **Đạo ôn · Bạc lá · Khô vằn · Đốm nâu**  
> Bắt buộc: cơ chế AI Safety + bước duyệt của Đại lý trước khi hiển thị gợi ý

| # | Màn hình | Widget / File gợi ý | Trạng thái |
|---|----------|---------------------|------------|
| 6.1 | Trang chính AI Scan | `AiScanHomeScreen` | `[ ]` |
| 6.2 | Chụp ảnh / Tải ảnh lá lúa | `ImageCaptureScreen` | `[ ]` |
| 6.3 | Đang phân tích (loading AI 10–15 giây) | `AiAnalyzingScreen` | `[ ]` |
| 6.4 | Kết quả chẩn đoán — có kết luận (tên bệnh + % confidence) | `DiagnoseResultScreen` | `[ ]` |
| 6.5 | ⚠️ Kết quả AI "Chưa đủ chắc chắn" (confidence thấp) | `DiagnoseUncertainScreen` | `[ ]` |
| 6.6 | Chờ đại lý duyệt gợi ý sản phẩm (pending approval) | `SuggestionPendingScreen` | `[ ]` |
| 6.7 | Gợi ý sản phẩm từ AI *(gắn nhãn "Gợi ý mang tính thương mại")* | `ProductSuggestionScreen` | `[ ]` |
| 6.8 | Lịch sử chẩn đoán của tôi | `DiagnoseHistoryScreen` | `[ ]` |

---

## 7. 👤 Hồ sơ & Cài đặt

| # | Màn hình | Widget / File gợi ý | Trạng thái |
|---|----------|---------------------|------------|
| 7.1 | Hồ sơ nông dân | `ProfileScreen` | `[ ]` |
| 7.2 | Chỉnh sửa thông tin cá nhân | `EditProfileScreen` | `[ ]` |
| 7.3 | Đổi mật khẩu | `ChangePasswordScreen` | `[ ]` |
| 7.4 | Cài đặt thông báo | `NotificationSettingsScreen` | `[ ]` |
| 7.5 | Điều khoản sử dụng | `TermsScreen` | `[ ]` |
| 7.6 | Chính sách bảo mật | `PrivacyScreen` | `[ ]` |
| 7.7 | Liên hệ hỗ trợ | `HelpSupportScreen` | `[ ]` |
| 7.8 | Đăng xuất (modal xác nhận) | *(component)* | `[ ]` |

---

## 8. 🔔 Màn hình phụ & Component dùng chung

| # | Màn hình | Widget / File gợi ý | Trạng thái |
|---|----------|---------------------|------------|
| 8.1 | Màn hình lỗi / Không có mạng | `ErrorScreen` | `[ ]` |
| 8.2 | Empty state (không có dữ liệu) | *(widget)* | `[ ]` |
| 8.3 | Modal xác nhận (xóa, ghi nợ, …) | *(widget)* | `[ ]` |
| 8.4 | Bottom Sheet chọn ảnh (camera / thư viện) | *(widget)* | `[ ]` |
| 8.5 | Loading overlay / Skeleton screen | *(widget)* | `[ ]` |

---

## 📌 Tổng kết tiến độ

| Module | Số màn hình | Hoàn thành |
|--------|:-----------:|:----------:|
| 1. Onboarding & Auth | 8 | 0 / 8 |
| 2. Home / Dashboard | 2 | 0 / 2 |
| 3. Sản phẩm & Đặt hàng | 6 | 0 / 6 |
| 4. Thanh toán QR VietQR | 3 | 0 / 3 |
| 5. Sổ nợ điện tử | 5 | 0 / 5 |
| 6. AI Chẩn đoán bệnh lúa | 8 | 0 / 8 |
| 7. Hồ sơ & Cài đặt | 8 | 0 / 8 |
| 8. Màn hình phụ | 5 | 0 / 5 |
| **Tổng** | **45** | **0 / 45** |

---

## 🗺️ Luồng chính (Main Flow) — theo Báo cáo đề tài

```
Nông dân:
Login → Home
  ├── [Mua hàng] → Xem SP → Giỏ hàng → Xác nhận → QR / Ghi nợ
  │     └── QR: Hiện QR → Chờ xác nhận → Kết quả ✅
  │     └── Nợ: Ghi vào Sổ nợ → Nông dân xác nhận 2 chiều ✅
  │
  └── [AI Scan] → Chụp ảnh → Phân tích (10–15s)
        ├── Confidence cao → Kết quả + Chờ duyệt → Gợi ý SP 🏷️ [Thương mại]
        └── Confidence thấp → ⚠️ "Chưa đủ chắc chắn" (KHÔNG đưa kết luận)
```

---

> 💡 **Quy ước:** `[ ]` → `[/]` khi bắt đầu · `[/]` → `[x]` khi hoàn thành  
> ⚙️ **Nền tảng:** Flutter · **Backend:** ASP.NET Core · **AI Service:** FastAPI (Python)  
> 📌 **Màn hình đã loại so với v1:** Field/Farm, Season/Crop, Activity Log, Supply/Warehouse, Calendar, Reports, Market Price (~28 màn hình ngoài scope)
