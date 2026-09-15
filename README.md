# AgriSage — Farmer Mobile App

Flutter mobile app cho nông dân trong hệ sinh thái AgriSage.

## Tech Stack
- **Flutter** (Dart)
- **GoRouter** — Navigation
- **Riverpod** — State management
- **Dio** — HTTP client
- **QR Flutter** — Hiển thị mã QR VietQR

## Cấu trúc
```
lib/
├── core/           # Theme, colors, typography
├── data/           # Models, mock data
├── features/       # Screens theo module
│   ├── auth/       # Login, Register, OTP...
│   ├── home/       # Dashboard
│   ├── products/   # Sản phẩm & Đặt hàng
│   ├── payment/    # QR VietQR
│   ├── debt/       # Sổ nợ điện tử
│   ├── ai_doctor/  # AI Chẩn đoán bệnh lúa
│   └── profile/    # Hồ sơ & Cài đặt
├── router/         # GoRouter config
└── shared/         # Shared widgets
```

## Màu sắc (bám sát Farmer-Web)
- Primary: #2E7D32
- Background: #F5FBF4
- Text: #172118

## Cài đặt
```bash
flutter pub get
flutter run
```
