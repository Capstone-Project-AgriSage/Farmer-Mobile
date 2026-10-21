# PROJECT_CONTEXT.md — Checkpoint (2026-10-14, cập nhật sau màn Công nợ)

## 1. PROJECT OVERVIEW
- **Tên**: AgriSage — app mobile cho NÔNG DÂN (repo `Farmer-Mobile`, package `farmer_mobile`, `applicationId = vn.agrisage.farmer`, `namespace` vẫn `com.example.farmer_mobile`).
- **Mục tiêu hệ thống**: nông dân mua vật tư nông nghiệp từ cửa hàng/đại lý, trả ngay qua payOS hoặc mua ghi nợ, theo dõi đơn/giao hàng, quản lý công nợ, trả hàng, gửi ảnh lá lúa để AI chẩn đoán ngay, nhận thông báo.
- **Tech stack**: Flutter 3.47.4 / Dart 3.13 (SDK `D:\Develop\flutter`), `flutter_riverpod` (Notifier/AsyncNotifier, KHÔNG codegen), `go_router`, `dio` + `pretty_dio_logger`, `flutter_secure_storage` (token), `shared_preferences` (khoản thanh toán dở), `webview_flutter` (trang payOS), `cached_network_image`, `image_picker`, `url_launcher`, `google_fonts` (Inter, Be Vietnam Pro, tải lúc chạy), `shimmer`, `intl` 0.20, `flutter_localizations` (locale vi), `integration_test`.
- **Backend**: ASP.NET (.NET 10) repo `Capstone-Project-AgriSage/Backend-Agrisage`, bản local của người dùng ở `D:\CAPSTONE BE\Backend-Agrisage` (chỉ đọc). Chạy: `dotnet run --project src/AgriSage.Api --urls http://localhost:5206`. Emulator gọi `http://10.0.2.2:5206`; máy thật `--dart-define=API_BASE_URL=http://<IP-LAN>:5206` hoặc `--dart-define-from-file=env/device.json`.
- **Kiến trúc app**: feature-first `lib/features/<feature>/{data,providers,screens,widgets}`; `lib/core/{config,network,auth,storage,utils,theme,constants}`; `lib/shared/widgets`; router `lib/router/app_router.dart` (guard `authRedirect`). Features: `auth, home, products (catalog + giỏ + xác nhận + màn đơn), orders (models/repo/widgets đơn), payment, debt, returns, ai_doctor, notifications, profile, dev`.
- **Role**: app chỉ cho tài khoản role `FARMER`. Nhân viên/chủ cửa hàng/tài xế dùng web (ngoài phạm vi).

## 2. CURRENT TASK
- **Task**: NÂNG CẤP GIAO DIỆN toàn app theo **phong cách hiện đại** (người dùng chọn ngày 2026-10-13), làm lần lượt từng màn. Mỗi màn: làm → test → ảnh chụp font thật → xem trên emulator → người dùng duyệt → commit.
- **Mục tiêu**: UI bớt đơn giản, đẹp và đồng bộ; tối ưu hiển thị (skeleton thay vòng quay, ảnh decode đúng kích thước); dễ dùng cho nông dân (chữ to không vỡ, vùng bấm lớn).
- **Yêu cầu**: giữ nguyên dữ liệu, chức năng, business rule, API; giữ màu thương hiệu xanh `#2E7D32` (Farmer-Web); không tràn layout ở 390px, 320px, cỡ chữ hệ thống x1.3/x1.6.
- **Đã duyệt + commit**: Trang chủ, Sản phẩm, Giỏ hàng & Xác nhận đặt hàng (+ `SectionCard`), Đơn hàng (`c99b932`, kèm 3 lỗi sửa).
- **Đang chờ duyệt (chưa commit)**: màn Công nợ (tổng quan, danh sách, chi tiết, trả nợ, lịch sử) + `DebtProgressBar`.
- **Ngoài scope**: thay đổi API/DB/business rule; tính năng chưa có API (bài viết, đánh giá, cài đặt thông báo, FCM, avatar, đổi SĐT/email); dark mode, đóng gói font, hiệu ứng chuyển trang (mới là đề xuất, CHƯA được yêu cầu).

## 3. COMPLETED
### Nối API (GĐ0–9, xong 2026-10-12)
- GĐ0 nền tảng: `AppConfig`, Dio + `AuthInterceptor` (Bearer, refresh token single-flight, refresh chủ động theo `exp`), `TokenStorage`, `ApiException` (RFC7807 → tiếng Việt), `apiCall`, `PagedResult`, `sessionProvider`.
- GĐ1 auth (đăng ký, đăng nhập có ghi nhớ, splash khôi phục phiên, quên & đặt lại mật khẩu bằng mã, đổi mật khẩu, OTP SĐT & email); GĐ2 hồ sơ + sổ địa chỉ; GĐ3 catalog + giỏ; GĐ4 đặt hàng/đơn/theo dõi giao hàng/huỷ; GĐ5 công nợ (tổng quan, danh sách, chi tiết, khiếu nại, trả nợ, lịch sử); GĐ6 trả hàng; GĐ7 chẩn đoán (chờ chuyên gia, nông dân KHÔNG thấy kết quả AI); GĐ8 thông báo; GĐ9 dọn mock, Trang chủ dữ liệu thật, danh sách phiên đăng nhập, `ComingSoonScreen`, `NotFoundScreen`, `MissingConfigApp`, E2E emulator.
### Gộp nhánh đồng đội `feature/mobile-diagnosis` (2026-10-13, commit `a481d2f`)
- payOS bằng WebView trong app (`lib/features/payment/...`): lưu khoản dở TRƯỚC khi mở trang, chặn trang trả về/huỷ theo path, link app ngân hàng giao cho hệ thống, màn kết quả luôn hỏi server (get rồi sync tối đa 5 lần), cổng thử, banner thanh toán dở ở Trang chủ, công cụ dev `SHOW_DEV_TOOLS` + `tool/payos_webview_test/`.
- Ảnh chẩn đoán: loại thật từ byte đầu (`photo_type.dart`), `PhotoPicker.recoverLost()`.
- Đặt hàng timeout → hộp thoại "có thể đã tạo đơn".
- CI `.github/workflows/flutter-ci.yml`, `env/*.json`, `applicationId`, locale vi, icon launcher. Gỡ `qr_flutter`.
- Commit `c35e7e3`: sửa chữ "Trả nợ bằng mã QR" ở onboarding & trợ giúp.
### Nâng cấp giao diện (2026-10-13/14)
- **Trang chủ** (`b44163f`): đầu trang xanh kéo lên thanh trạng thái (lời chào theo giờ, tên, ngày, chuông trong nút tròn), thẻ 4 lối tắt đè mép (Mua sắm, Giỏ hàng có số món, Đơn hàng, Công nợ có chấm đỏ khi quá hạn), thẻ "Khám bệnh cho cây lúa" nền xanh nhạt, tiêu đề mục ngoài thẻ, số đơn có màu, skeleton shimmer; màn < 360px ẩn minh hoạ và thu nhỏ ô lối tắt. Sửa lỗi: dòng "Kết luận do chuyên gia xác nhận" chỉ hiện với ca VERIFIED.
- **Sản phẩm** (`ee951e0`): danh sách (tiêu đề lớn, ô tìm bo tròn, chip danh mục có icon theo tên `categoryIcon()`, thẻ ảnh bo góc + nhãn danh mục đè ảnh, skeleton thẻ); chi tiết (ảnh 4:3 tối đa cao 300, thẻ thông tin, chọn quy cách bằng ô có tích, mục nội dung trong thẻ có icon, thanh đáy có "Tạm tính" = giá × số lượng, skeleton). `ProductImage` decode theo kích thước hiển thị (`memCacheWidth`) + fade-in, ô chờ nền xanh có hình lá.
- **Giỏ & xác nhận** (`11a3b8d`): giỏ (tiêu đề + số sản phẩm, thẻ dòng hàng ảnh lớn, nút xoá tròn, thành tiền cạnh stepper; chiều rộng nội dung < 230px thì thành tiền xuống dòng riêng); xác nhận (thanh bước Giỏ hàng → Xác nhận → Thanh toán, màn hẹp chỉ ghi chữ bước hiện tại; ô chọn có icon + tích; địa chỉ & sản phẩm có ảnh nhỏ; ô đồng ý thành thẻ). `SectionCard` (dùng ở 7 màn: chi tiết đơn, công nợ tổng quan/chi tiết/trả nợ, trả hàng, chẩn đoán, xác nhận đặt hàng) bo 18 + bóng mềm + icon trong ô xanh; 30 tiêu đề chuyển từ IN HOA sang chữ thường. Sửa lỗi: màn xác nhận tải lại giỏ 2 lần.

## 4. IN PROGRESS
- **Màn Chẩn đoán: code + test + ảnh chụp (390/320, quét cỡ chữ) XONG, CHƯA COMMIT, chờ duyệt.** Màn chính (hero xanh thương hiệu thay tím, thẻ bệnh bóng mềm, key scan_start), lịch sử (chip bo tròn, thẻ), chụp ảnh (thẻ xem trước bo 24, nút gửi màu chính), chi tiết ca (đầu thẻ có icon, kết luận bo 20, skeleton, thanh đáy bo góc), DiagnosisPhoto dùng shimmer. Chưa xem trên emulator (dev server không có model AI, ca thật ở trạng thái chờ).
- **Các màn còn lại (Trả hàng, Kết quả thanh toán, Đăng nhập/Welcome, Hồ sơ con) đã làm kiểu hiện đại, CHƯA COMMIT.** Theme chung: AppBar phẳng, bo nút/ô nhập 14, nhãn ô nhập chữ thường. Hoàn tất lượt nâng cấp giao diện toàn app; analyze sạch, 690 test, 204 ảnh/quét cỡ chữ pass.
- (Đã commit c240422) Thông báo + Hồ sơ; (af168ef) Chẩn đoán; (da6a387) Công nợ. `debt_widgets.dart` (`DebtEntryCard` thẻ bóng mềm + icon + nhãn + thanh `debt_entry_progress`, `DebtProgressBar` mới), `debt_overview_screen.dart` (thẻ hạn mức gradient xanh + thanh `credit_usage` = dư nợ/hạn mức, skeleton), `debt_detail_screen.dart` (nhãn 'Còn phải trả'/'Giá trị khoản nợ' chuyển sang chữ thường, thanh `debt_progress`, biến động có mũi tên, thanh đáy bo góc), `debt_list_screen.dart` (chip bo tròn), `debt_history_screen.dart`, `debt_repay_screen.dart`; test cập nhật. Kiểm tra: analyze sạch, 690 test pass, ảnh 390/320 và quét cỡ chữ pass. CHƯA xem trên emulator (tài khoản test không có hạn mức → chỉ thấy trạng thái trống).
- (Đã commit `c99b932`) Màn Đơn hàng — mô tả bên dưới giữ để tham khảo.
- **Màn Đơn hàng (đã commit `c99b932`, chưa push)**:
  - `lib/features/products/screens/order_list_screen.dart`: bộ lọc chip bo tròn (`Material` + key `order_filter_*`), thẻ đơn (icon giao/nhận tô màu trạng thái, mã đơn đủ, "Đặt lúc …", hàng nhãn gồm trạng thái + hình thức + thanh toán + số sản phẩm, tổng tiền), widget `_Pill`.
  - `lib/features/products/screens/order_detail_screen.dart`: khối đầu (icon, mã, ngày, badge dưới ngày), `_StatusTimeline` 5 bước (Đặt hàng → Xác nhận → Chuẩn bị → Giao hàng / Sẵn sàng nhận / Giao một phần → Hoàn thành / Huỷ phần còn lại). `reached()`: pending 0, confirmed 1, preparing 2, ready|partiallyFulfilled 3, còn lại 4. Đơn CANCELLED không có timeline. Lời nhắc trong khung màu, thanh tiến độ `pay_progress` (chỉ đơn trả ngay, không huỷ), thanh đáy bo góc.
  - 3 lỗi phát hiện khi đặt thử đơn thật `OD-20261014-0001` (đã huỷ ngay; đơn vẫn còn trên DB):
    1. Lý do huỷ mặc định tiếng Anh → `OrderStatus.backendDefaultCancelReason` + `cancelReasonLabel()` trong `lib/features/orders/data/order_models.dart`.
    2. Đơn huỷ vẫn báo "Còn phải trả" → ẩn dòng đó và thanh tiến độ, hiện `pay_cancelled_note`.
    3. Nút Back hệ thống thoát app khi màn mở bằng `context.go` → `lib/shared/widgets/fallback_pop_scope.dart`, gắn ở router cho `/orders`, `/orders/:id`, `/returns/:id`.
  - Kiểm tra: `flutter analyze` sạch; `flutter test` 689 pass (324 skip); ảnh chụp + quét cỡ chữ 202 pass. Lỗi 1 và 2 đã xem trên emulator với đơn thật; lỗi 3 chỉ kiểm bằng test (`test/features/shared/fallback_pop_scope_test.dart`, đã xác nhận khi chưa sửa thì `handlePopRoute` trả `false`).

## 5. TODO (theo ưu tiên)
1. Người dùng duyệt màn Đơn hàng → commit (chưa push; 3 commit UI trước cũng CHƯA push).
2. Nâng cấp giao diện các màn còn lại theo cùng phong cách: Công nợ (tổng quan, danh sách, chi tiết — khối "CÒN PHẢI TRẢ" còn kiểu cũ — trả nợ, lịch sử), Chẩn đoán (AI scan home, chụp ảnh, chi tiết ca, lịch sử), Thông báo, Hồ sơ, Trả hàng, Kết quả thanh toán, Auth (đăng nhập/đăng ký/onboarding), Sổ địa chỉ, Trợ giúp/điều khoản. Thứ tự: UNCONFIRMED (người dùng chọn).
3. Đề xuất đã nêu nhưng CHƯA được yêu cầu: đóng gói font vào app, hiệu ứng chuyển trang/hero ảnh, rung nhẹ, banner mất kết nối, dark mode.
4. Sau khi xong UI: chạy lại E2E `integration_test/app_flow_test.dart` (có thể cần chỉnh finder theo giao diện mới); push và mở PR `feature/mobile-api-integration` → `main` chỉ khi người dùng yêu cầu.

## 6. FILES CHANGED
### Chưa commit (màn Đơn hàng)
- `lib/features/products/screens/order_list_screen.dart`: giao diện mới danh sách đơn (mục 4). Phụ thuộc `orders/data/order_models.dart`, `orders/widgets/order_widgets.dart` (`OrderStatusBadge`, `formatDateTime`).
- `lib/features/products/screens/order_detail_screen.dart`: khối đầu + `_StatusTimeline`, khung lời nhắc, `pay_progress`, ẩn "Còn phải trả" khi huỷ, dịch lý do huỷ, thanh đáy bo góc. Phụ thuộc `SectionCard`/`InfoRow`/`StatusChip` (order_widgets), payment providers.
- `lib/features/orders/data/order_models.dart`: thêm `OrderStatus.backendDefaultCancelReason`, `cancelReasonLabel()` (vì backend tự ghi câu tiếng Anh khi không có lý do).
- `lib/router/app_router.dart`: bọc `OrderListScreen`, `OrderDetailScreen`, `ReturnDetailScreen` bằng `FallbackPopScope`; thêm import.
- `lib/shared/widgets/fallback_pop_scope.dart` (mới): `PopScope` về route dự phòng khi `!GoRouter.canPop()`.
- `test/features/orders/order_screens_test.dart`: test timeline (7 trạng thái), nhãn bước, huỷ phần còn lại, đơn huỷ, thanh tiến độ (trả ngay/ghi nợ), lý do huỷ, ghi chú đơn huỷ, `cancelReasonLabel`; sửa test nhãn thẻ đơn.
- `test/features/shared/fallback_pop_scope_test.dart` (mới).
- `PROJECT_CONTEXT.md`: checkpoint này.
### Đã commit trong đợt UI, chưa push (`b44163f`, `ee951e0`, `11a3b8d`)
- `lib/features/home/screens/home_screen.dart`, `lib/features/notifications/widgets/notification_bell.dart` (thêm tham số `color`), `test/features/home/home_screen_test.dart`.
- `lib/features/products/widgets/product_widgets.dart` (`ProductImage`, `categoryIcon`, `ProductCard`), `screens/product_list_screen.dart`, `screens/product_detail_screen.dart`, `test/features/products/product_screens_test.dart`.
- `lib/features/products/screens/cart_screen.dart`, `screens/order_confirm_screen.dart` (`_CheckoutSteps`, `_OptionTile` có icon), `lib/features/orders/widgets/order_widgets.dart` (`SectionCard` kiểu mới); tiêu đề `SectionCard` sang chữ thường ở `ai_doctor/screens/diagnose_case_screen.dart`, `debt/screens/{debt_detail,debt_overview,debt_repay}_screen.dart`, `products/screens/{order_confirm,order_detail}_screen.dart`, `returns/screens/return_detail_screen.dart`; test liên quan (`checkout_screen_test`, `diagnosis_screens_test`, `order_screens_test`).

## 7. NEXT FILES
- Nếu người dùng duyệt Đơn hàng: commit các file ở mục 6 (phần chưa commit).
- Màn tiếp theo (người dùng chọn; gợi ý Công nợ): `lib/features/debt/screens/debt_overview_screen.dart`, `debt_list_screen.dart`, `debt_detail_screen.dart` (khối "Còn phải trả" kiểu cũ), `debt_repay_screen.dart`, `debt_history_screen.dart`, `lib/features/debt/widgets/debt_widgets.dart`; test `test/features/debt/*`, ảnh `test/visual/debt_screenshots_test.dart`.
- Hoặc Chẩn đoán: `lib/features/ai_doctor/screens/{ai_scan_home,image_capture,diagnose_case,diagnose_history}_screen.dart`, `widgets/diagnosis_widgets.dart`.

## 8. API / DATABASE / DATA CONTRACT
Tất cả dưới `/api`; nông dân dùng `/me/*` (danh tính từ JWT). Danh sách trả `PagedResult{items,page,pageSize,totalCount,totalPages}` (pageSize ≤ 100). Lỗi RFC7807 `{title,status,detail,errors?,traceId}`.
- **Auth**: `POST auth/register{fullName,phoneNumber?,email?,password}`; `auth/login{identifier,password}` → `{accessToken,refreshToken,sessionId,user{id,fullName,phoneNumber,email,role}}`; `auth/refresh`; `auth/logout`, `logout-all`; `GET auth/sessions`, `DELETE auth/sessions/{id}`; `GET auth/me`; `auth/change-password` (401 = sai mật khẩu hiện tại; thành công huỷ mọi phiên); `auth/forgot-password{identifier}` (202; 503 nếu chưa cấu hình gửi tin); `auth/reset-password{token,newPassword}`; `auth/phone-verification/{request,confirm{code}}`; `auth/email-verification/{request,confirm}`. Mã gửi qua SMTP (email) hoặc cổng SMS HTTPS (`AuthMessageSender.cs`, cần `SmtpHost/FromEmail` hoặc `SmsGatewayUrl/SmsApiKey`).
- **Hồ sơ/địa chỉ**: `GET/PUT me/profile`; `me/addresses` GET/POST, `PUT/DELETE {id}`, `POST {id}/set-default`.
- **Catalog**: `catalog/categories`, `catalog/products?page&pageSize&categoryId&search`, `catalog/products/{storeProductId}`.
- **Giỏ**: `GET me/cart`, `POST me/cart/items`, `PUT/DELETE me/cart/items/{id}`, `DELETE me/cart`. Dòng có `isAvailable`, `unavailableReason NOT_SELLABLE|NO_PRICE`.
- **Đơn**: `POST me/orders{source:"FARMER_MOBILE",settlementType FULL_PAYMENT|CREDIT,fulfillmentType DELIVERY|PICKUP,addressId?,note?}`; `GET me/orders?status&page&pageSize` (lọc MỘT trạng thái); `GET me/orders/{id}` (có `cancelReason`, `confirmedAt`, `completedAt`, `address`, `items[]` KHÔNG có ảnh); `POST me/orders/{id}/cancel{reason?}` (không có lý do thì backend ghi `"Cancelled by the customer."` = `MeOrderService.DefaultCancelReason`); `GET me/orders/{id}/deliveries`; `GET me/orders/{id}/payments` → `{orderTotal,paidAmount,remainingToPay,payments[],refunds[]}` (đơn đã huỷ vẫn có thể ra `remainingToPay` > 0).
- **Thanh toán**: `POST me/payments/payos{paymentContext ORDER_PAYMENT|DEBT_REPAYMENT,orderId?,amount?}` → `{paymentId,paymentNumber,amount,checkoutUrl,qrCode,expiresAt,status}`; `GET me/payments/{id}`; `POST payments/{id}/sync`; `POST me/payments/{id}/cancel`; `POST payments/{id}/simulate-paid` (chỉ `PayOS:Mode=Simulated`).
- **Công nợ**: `GET me/credit` (404 = chưa cấp), `GET me/debt`, `GET me/debt-entries`, `GET me/debt-entries/{id}`, `POST …/dispute`, `GET me/debt/allocation-preview?amount`.
- **Trả hàng / chẩn đoán / thông báo**: như đã nối ở GĐ6–8 (xem `lib/features/{returns,ai_doctor,notifications}/data`).
- **Enum**: Order `PENDING_CONFIRMATION, CONFIRMED, PREPARING, READY_FOR_FULFILLMENT, PARTIALLY_FULFILLED, COMPLETED, CANCELLED, PARTIALLY_CANCELLED`; Payment `PENDING, PAID, FAILED, CANCELLED, PARTIALLY_REFUNDED, REFUNDED`; Delivery `ASSIGNED, OUT_FOR_DELIVERY, PARTIALLY_DELIVERED, RETRY_PENDING, DELIVERED, CANCELLED`; Diagnosis gồm `AI_COMPLETED, UNDER_REVIEW, VERIFIED, INCONCLUSIVE, CANCELLED` (danh sách đầy đủ: xem `diagnosis_models.dart`).
- **Chưa có API**: bài viết, đánh giá sản phẩm, cài đặt thông báo, push/FCM, upload avatar, đổi SĐT/email, tồn kho ở catalog, ảnh của dòng hàng trong đơn.

## 9. BUSINESS RULES (đã chốt, không tự đổi)
- Chỉ role `FARMER`. Đổi mật khẩu huỷ mọi phiên. Xác minh SĐT/email không bắt buộc.
- Giỏ không giữ hàng, giá server tính lại mỗi lần (giỏ là giá chính thức); dòng `isAvailable=false` chặn đặt hàng.
- DELIVERY cần đúng một `addressId`; PICKUP không gửi địa chỉ. Đặt xong thì giỏ rỗng.
- Chỉ huỷ online khi `PENDING_CONFIRMATION`. Đơn trả ngay + giao tận nơi: cửa hàng chỉ xác nhận khi đã nhận đủ tiền → app tự mở thanh toán sau khi đặt. `canPay` = không phải CANCELLED/PARTIALLY_CANCELLED/COMPLETED.
- Tiền chỉ tính đã trả khi server báo `PAID` (không tin link trả về payOS).
- Mua ghi nợ cần hồ sơ tín dụng ACTIVE và đủ hạn mức; trả nợ phân bổ khoản đến hạn sớm nhất trước.
- Chẩn đoán (AI_DIAGNOSIS.md 2.0, từ 21/10/2026): không còn bước duyệt; nông dân thấy kết quả AI ngay. `CONFIDENT` có cách xử lý và sản phẩm gợi ý; `UNCERTAIN` không có thuốc/sản phẩm, khuyên chụp lại hoặc hỏi cửa hàng; `FAILED` có nút Thử lại (`POST /api/me/diagnosis-cases/{id}/retry`). Ca cũ `VERIFIED`/`INCONCLUSIVE` vẫn đọc được. Không hiện xác suất.
- **Hiển thị đơn (chốt trong đợt UI)**: đơn CANCELLED không hiện timeline và không hiện "Còn phải trả" (ghi "Đơn đã huỷ, bạn không cần thanh toán thêm"); lý do huỷ mặc định của backend hiện "Bạn đã huỷ đơn này", lý do người dùng tự nhập giữ nguyên; đơn ghi nợ không có thanh tiến độ thanh toán; PARTIALLY_CANCELLED có bước cuối ghi "Huỷ phần còn lại" (màu cam), không ghi "Hoàn thành".

## 10. DECISIONS
- **UI**: phong cách hiện đại (người dùng chọn); giữ màu xanh thương hiệu; thẻ trắng bo 18–20 + bóng mềm (không viền); tiêu đề mục chữ thường đậm (không IN HOA); icon trong ô màu nhạt; chip/nhãn bo tròn; thanh đáy bo góc trên 24; skeleton shimmer thay vòng quay; màn hẹp (< 360px) tự thu gọn (ẩn minh hoạ, chỉ nhãn bước hiện tại, thành tiền xuống dòng).
- **Quy trình**: mỗi màn làm xong → test + ảnh chụp font thật 390/320 + quét cỡ chữ → xem trên emulator → người dùng duyệt → commit (không push nếu chưa được yêu cầu).
- **Kiến trúc**: Riverpod không codegen; mỗi feature có repository; `ApiException` thống nhất; widget dùng chung ở `lib/shared/widgets` hoặc `orders/widgets/order_widgets.dart` (`SectionCard`, `InfoRow`, `StatusChip`).
- Nhánh làm việc `feature/mobile-api-integration` là nền; nhánh đồng đội được chuyển tay từng phần (không `git merge`).
- Test: fake repository + `AppHarness`; live test `LIVE_API=1`; ảnh chụp `SCREENSHOTS=1 FLUTTER_ROOT=/d/Develop/flutter flutter test --update-goldens test/visual/` rồi xem và XOÁ `test/visual/shots`.

## 11. BLOCKERS / OPEN QUESTIONS
- **payOS chưa cấu hình trên server dev** (tạo link trả 503) → chưa thử thanh toán thật; WebView chỉ thử với trang giả. Cần Backend cấu hình khoá payOS hoặc `PayOS:Mode=Simulated`. Ảnh hưởng: thanh toán đơn, trả nợ.
- **Tài khoản test chưa có hạn mức** (`GET me/credit` 404) → công nợ có dữ liệu và mua ghi nợ thành công chỉ test bằng fake. Ảnh hưởng: xem UI Công nợ với dữ liệu thật. Cần cửa hàng/Backend cấp hạn mức cho một tài khoản test.
- **SMTP/SMS chưa cấu hình** → quên mật khẩu & OTP trả 503. Cần Backend cấu hình `appsettings.Local.json`.
- **Màn làm tiếp sau Đơn hàng**: UNCONFIRMED, chờ người dùng chọn (Công nợ, Chẩn đoán…).
- Chẩn đoán có kết quả thật cần AI-Service chạy artifact 0.2.0; AI-Service tắt thì ca thành FAILED (nông dân bấm Thử lại khi AI chạy lại).

## 12. ERRORS / KNOWN ISSUES
- **Môi trường**: BE, adb, emulator do Claude khởi động bị dừng khi kết thúc lượt trả lời → mọi bước cần emulator/BE phải làm trọn trong MỘT lượt. Máy chỉ còn ~0,5 GB RAM trống khi chạy emulator → emulator hay tự tắt. Khởi động bằng PowerShell `Start-Process emulator.exe -avd Pixel_7 -no-snapshot -no-audio -no-boot-anim -memory 3072 -gpu swiftshader_indirect`, chờ ~90–100s; tắt Gradle daemon (`taskkill /F /IM java.exe`) để đỡ RAM.
- Build Android cần `ORG_GRADLE_PROJECT_android.aapt2FromMavenOverride=C:/Users/WIN10/AppData/Local/Android/Sdk/build-tools/36.1.0/aapt2.exe`.
- Xem app: `flutter run -d emulator-5554 --dart-define=SHOW_DEV_TOOLS=true`, điều khiển bằng `adb shell input tap/swipe` + `adb exec-out screencap -p` (toạ độ trên ảnh hiển thị × 1,2 = toạ độ thật). Tài khoản đang đăng nhập trên emulator: "quan" (giỏ trống sau khi đặt đơn thử).
- Không chạm được vào WebView từ test binding → muốn thao tác WebView phải `flutter run` + adb.
- `tester.pageBack()` tìm tooltip "Back" tiếng Anh → hỏng với locale vi; E2E bấm `BackButton` trực tiếp.
- Trình chụp của `flutter test` vẽ bóng đổ thành dải cứng dưới thẻ (không có trên máy thật).
- Heredoc bash chứa `'` lồng, và perl với chuỗi có `/`, hay lỗi → dùng Write/Edit; máy không có Python (dùng node/perl/sed).
- DB dev dùng chung không xoá được dữ liệu test: nhiều tài khoản "TEST Mobile …", các đơn đã huỷ, đơn `OD-20261014-0001` (tài khoản "quan", đã huỷ).

## 13. DO NOT CHANGE
- Business rule mục 9, API contract mục 8, database (không có quyền, không đụng).
- UI đã được duyệt: Trang chủ, Sản phẩm (danh sách/chi tiết), Giỏ hàng, Xác nhận đặt hàng, `SectionCard` kiểu mới.
- Key widget đang được test/E2E dùng (vd. `home_greeting`, `home_qa_*`, `product_count`, `product_<id>`, `add_to_cart`, `cart_checkout`, `checkout_submit`, `opt_pickup`, `order_agree`, `order_number`, `order_cancel`, `cancel_confirm`, `order_filter_*`, `order_<id>`, `order_timeline`, `pay_progress`, `payos_stub`…).
- Quy ước: tiếng Việt cho mọi chữ hiển thị; tên file/provider theo mẫu hiện có; không commit/push/merge/branch/reset/checkout khi chưa được yêu cầu; không dùng tài khoản admin/nhân viên trong cấu hình BE để sửa DB dùng chung; code ngoài scope không tự sửa.

## 14. ASSUMPTIONS
- Backend dev ở `localhost:5206` do người dùng chạy (Claude có thể tự bật để kiểm tra, đã làm nhiều lần).
- Giờ trên emulator là giờ thật (lời chào theo giờ dựa vào đó).
- Các màn còn lại sẽ được nâng cấp theo cùng phong cách: thứ tự UNCONFIRMED.
- `PARTIALLY_CANCELLED` được coi là trạng thái kết thúc (bước cuối) trong timeline, suy ra từ `canPay`: UNCONFIRMED với Backend.

## 15. GIT STATUS
- Branch: `feature/mobile-api-integration`. `main` = `b92551f`.
- Đã push tới `c35e7e3`. Chưa push: `b44163f` (Trang chủ), `ee951e0` (Sản phẩm), `11a3b8d` (Giỏ & xác nhận).
- Chưa commit: `M lib/features/orders/data/order_models.dart`, `M lib/features/products/screens/order_detail_screen.dart`, `M lib/features/products/screens/order_list_screen.dart`, `M lib/router/app_router.dart`, `M test/features/orders/order_screens_test.dart`, `?? lib/shared/widgets/fallback_pop_scope.dart`, `?? test/features/shared/fallback_pop_scope_test.dart`, `M PROJECT_CONTEXT.md`.
- Nhánh đồng đội `origin/feature/mobile-diagnosis` để nguyên. Chưa có PR.
- KHÔNG commit/push/merge/reset/checkout khi người dùng chưa yêu cầu.

## 16. CONTINUE FROM HERE
1. **Chờ người dùng duyệt màn Đơn hàng.** Nếu duyệt: commit các file chưa commit ở mục 6 (chưa push), message kiểu `feat(mobile): modern order list and order detail` nêu cả 3 lỗi đã sửa, kết thúc bằng dòng `Co-Authored-By` theo hướng dẫn hệ thống hiện hành.
2. Nhận lựa chọn màn tiếp theo (gợi ý **Công nợ**). Mở đầu tiên `lib/features/debt/screens/debt_overview_screen.dart` và `lib/features/debt/widgets/debt_widgets.dart`; sau đó `debt_detail_screen.dart` (khối "Còn phải trả" kiểu cũ), `debt_list_screen.dart`, `debt_repay_screen.dart`, `debt_history_screen.dart`.
3. Với mỗi màn: đọc test hiện có (`test/features/<feature>`) để giữ key/chữ → viết giao diện theo phong cách mục 10 → `flutter analyze` → test → `SCREENSHOTS=1 … test/visual/` (xem ảnh 390/320) → quét cỡ chữ → xoá `test/visual/shots` → bật BE + emulator + `flutter run` trong CÙNG một lượt để xem dữ liệu thật → báo người dùng.
4. Giữ nguyên mục 9 và 13; không đổi API; không mở rộng scope (dark mode, đóng gói font… chỉ làm khi được yêu cầu).
5. Lưu ý trước khi làm Công nợ: tài khoản test không có hạn mức nên với dữ liệu thật chỉ xem được trạng thái "chưa có sổ nợ"; màn có dữ liệu chỉ kiểm bằng ảnh chụp dữ liệu giả.

## 17. QUICK RECOVERY SUMMARY
App Flutter cho nông dân AgriSage đã nối đủ API backend ASP.NET (local :5206) và gộp phần tốt của nhánh đồng đội (payOS WebView…). Đang **nâng cấp giao diện theo phong cách hiện đại** từng màn: đã duyệt + commit Trang chủ, Sản phẩm, Giỏ hàng & Xác nhận (3 commit chưa push). **Màn Đơn hàng** (danh sách + chi tiết có dòng thời gian trạng thái và thanh tiến độ thanh toán) đã xong, kèm sửa 3 lỗi thật (lý do huỷ tiếng Anh, đơn huỷ vẫn báo còn phải trả, nút Back hệ thống thoát app); 689 test pass, ảnh chụp/quét cỡ chữ pass; CHƯA commit, chờ duyệt. Còn lại: Công nợ, Chẩn đoán, Thông báo, Hồ sơ, Trả hàng, Auth… Blocker: payOS/SMTP chưa cấu hình, tài khoản test không có hạn mức. Môi trường: emulator/BE do Claude bật sẽ tắt sau mỗi lượt, máy thiếu RAM. Bước tiếp: người dùng duyệt Đơn hàng → commit → làm màn tiếp theo (gợi ý Công nợ).
