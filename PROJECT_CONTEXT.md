# PROJECT_CONTEXT.md — Checkpoint (2026-10-12)

## 1. PROJECT OVERVIEW
- **Tên**: AgriSage — app mobile cho NÔNG DÂN (`Farmer-Mobile`, package `farmer_mobile`).
- **Mục tiêu**: nông dân mua vật tư nông nghiệp từ cửa hàng/đại lý, chẩn đoán bệnh lúa bằng AI, quản lý công nợ. Nhiệm vụ hiện tại: thay toàn bộ dữ liệu mock bằng API backend thật.
- **Tech stack (mobile)**: Flutter 3.47 (SDK `D:\Develop\flutter`), Dart, `flutter_riverpod` (Notifier/AsyncNotifier, KHÔNG dùng codegen), `go_router`, `dio` + `pretty_dio_logger`, `flutter_secure_storage`, `cached_network_image`, `qr_flutter`, `url_launcher`, `google_fonts` (Inter, Be Vietnam Pro), `shimmer`, `intl`.
- **Backend**: repo `https://github.com/Capstone-Project-AgriSage/Backend-Agrisage` (ASP.NET .NET 10, Supabase Postgres, JWT + refresh token xoay vòng). Chạy local `http://localhost:5206` (Swagger `/swagger`, chỉ Development). Android emulator: `http://10.0.2.2:5206`; máy thật: `--dart-define=API_BASE_URL=http://<IP-LAN>:5206`.
- **Kiến trúc app**: feature-first `lib/features/<feature>/{data,providers,screens,widgets}`; `lib/core/{config,network,auth,utils,theme,constants}`; `lib/shared/widgets`; router `lib/router/app_router.dart`. Mỗi feature: models + repository (Dio) + provider (Riverpod) + screens.
- **Role**: app chỉ dành `FARMER` (đăng nhập role khác bị từ chối). Nhân viên/chủ cửa hàng/tài xế dùng web quản lý (ngoài phạm vi).

## 2. CURRENT TASK
- Nối API backend cho app nông dân theo kế hoạch 10 giai đoạn (0–9). **Tất cả giai đoạn 0–9 đã xong** (2026-10-12); chờ người dùng review và tự commit/push.
- Yêu cầu của người dùng cho mỗi giai đoạn: làm xong rồi "test thật kĩ cả giao diện và code" (unit/widget/live/ảnh chụp font thật).
- **Ngoài scope**: (không còn giai đoạn nào sau GĐ9); bài viết, đánh giá sản phẩm, push FCM, avatar upload, đổi SĐT/email (backend chưa có API).

## 3. COMPLETED
Các giai đoạn đều có: repository + provider + màn hình thật + test.
- **GĐ0 Nền tảng**: `AppConfig` (base URL theo nền tảng, timeout), Dio client + interceptor (Bearer, refresh token single-flight, refresh chủ động bằng `exp` JWT, tôn trọng header `Authorization` do nơi gọi chỉ định, không refresh cho login/register/refresh/forgot/reset/change-password/catalog), `TokenStorage` (secure storage + chế độ không ghi nhớ), `ApiException` (map RFC7807 → tiếng Việt, `fieldErrors`, `isConnectivity`, `withMessage`), `PagedResult`, `json_utils`, `sessionProvider`. Manifest: INTERNET + cleartext chỉ ở debug.
- **GĐ1 Auth**: đăng ký/đăng nhập/splash khôi phục phiên (offline → "Thử lại")/đăng xuất/quên & đặt lại mật khẩu (dán mã)/đổi mật khẩu (huỷ mọi phiên → đăng xuất cục bộ)/xác minh SĐT (OTP) & email (dán mã). Router guard `authRedirect`. Validators khớp backend (SĐT VN, mật khẩu 8–128).
- **GĐ2 Hồ sơ & địa chỉ**: sửa hồ sơ (tên, ngày sinh, giới tính; SĐT/email chỉ đọc), sổ địa chỉ CRUD + đặt mặc định (tối đa 10, ward/district tuỳ chọn), `Address` model theo backend.
- **GĐ3 Catalog & giỏ**: danh mục, danh sách sản phẩm (tìm debounce 400ms, lọc danh mục, cuộn vô hạn), chi tiết (chọn quy cách, số lượng, hoạt chất, sản phẩm liên quan), giỏ hàng (+/−, xoá, xoá tất cả, dòng `NOT_SELLABLE`/`NO_PRICE` chặn đặt hàng), badge giỏ, Home chào tên thật. `formatVnd`.
- **GĐ4 Đơn hàng & thanh toán**: màn xác nhận đặt hàng (giao/nhận tại cửa hàng, chọn địa chỉ, ghi chú, trả ngay/ghi nợ theo hạn mức), danh sách đơn (lọc, phân trang), chi tiết đơn (thanh toán, huỷ khi `PENDING_CONFIRMATION`, theo dõi giao hàng + tài xế + ảnh bằng chứng), màn payOS QR (polling 3s, sync khi chờ lâu/khi bấm, hết hạn, huỷ, resume app), màn kết quả. Dữ liệu mock đơn hàng đã xoá.
- **GĐ5 Công nợ & hạn mức (2026-10-12)**: `lib/features/debt/{data/debt_models,data/debt_repository,providers/debt_providers,widgets/debt_widgets}.dart`; 5 màn: tổng quan (thẻ hạn mức + tổng nợ + banner quá hạn + khoản sắp đến hạn), danh sách (lọc: Tất cả/Chưa trả/Trả một phần/Quá hạn/Khiếu nại/Đã trả, cuộn vô hạn), chi tiết (sản phẩm, biến động, khiếu nại + hộp thoại), **trả nợ** (`debt_repay_screen.dart`, thay màn "xác nhận 2 chiều" mock vì backend không có), lịch sử trả nợ (lọc `DEBT_REPAYMENT` từ `me/payments`). `PaymentRepository.createForDebt`; `QRPaymentScreen` nhận `orderId` HOẶC `debtAmount`; kết quả `?kind=debt`; chấm đỏ tab Công nợ khi có nợ quá hạn (`hasOverdueDebtProvider`). Đã xoá `lib/data/models/debt.dart`, `mock_debts.dart`, `debt_confirm_screen.dart`. Route `/debt/history` và `/debt/repay` đứng TRƯỚC `/debt/:id`.
- **GĐ6 Trả hàng (2026-10-12)**: `lib/features/returns/{data/return_models,data/return_repository,providers/return_providers,widgets/return_widgets,screens/{return_request,return_list,return_detail}_screen}.dart`. Lối vào: mục "TRẢ HÀNG" ở chi tiết đơn (chỉ khi `OrderStatus.canReturn`: PARTIALLY_FULFILLED/COMPLETED/PARTIALLY_CANCELLED) + tile "Yêu cầu trả hàng" ở Profile. Routes `/orders/:id/return`, `/returns`, `/returns/:id`. Số lượng backend tính theo ĐƠN VỊ NHỎ NHẤT (base); app cho chọn theo đơn vị bán (bao...) = base/`conversionToBase`, rồi chia qua các nguồn (lô) bằng `ReturnLineRequest.allocate` (mỗi dòng gửi đúng MỘT trong `deliveryItemLotAllocationId` / `originalStockMovementItemId`). Tên sản phẩm ở chi tiết trả hàng lấy từ `orderDetailProvider` (response trả hàng không có tên). Rejected/cancelled ẩn mục "Tiền hoàn lại". Test: `test/features/returns` (58), `test/live/returns_live_test.dart` (10), `test/visual/returns_screenshots_test.dart`.
- **GĐ7 AI Doctor (2026-10-12)** — THEO LUỒNG BACKEND: nông dân KHÔNG thấy kết quả AI; mọi ca chờ chuyên gia (nhân viên có `can_review_ai`) duyệt, chỉ ca VERIFIED có bệnh/điều trị/sản phẩm. `lib/features/ai_doctor/{data/{diagnosis_models,diagnosis_repository},providers/diagnosis_providers,widgets/diagnosis_widgets}.dart`; màn: `ai_scan_home` (chữ đã sửa, 5 lớp gồm Healthy), `image_capture` (chụp/chọn ảnh + ghi chú + gửi, `PhotoPicker` tách để test), `diagnose_case_screen` (mới: chờ / có kết quả / cần chụp lại / đã huỷ + huỷ ca + tự làm mới 30s khi còn chờ), `diagnose_history` (lọc: Tất cả/Đã có kết quả/Cần chụp lại/Đã huỷ; KHÔNG có lọc "đang chờ" vì backend lọc 1 trạng thái). Sản phẩm gợi ý mở `/products/{storeProductId}`. Routes `/ai-scan/capture`, `/ai-scan/case/:id`, `/ai-scan/history`. Đã xoá màn/model mock: ai_analyzing, diagnose_result, diagnose_uncertain, suggestion_pending, product_suggestion, `models/diagnose.dart`, `mock_diagnoses.dart`. Test: `test/features/ai_doctor` (58), `test/live/diagnosis_live_test.dart` (9, upload multipart thật OK), `test/visual/diagnosis_screenshots_test.dart`. Dev server chưa có model AI nên ca thật thành FAILED (vẫn "chờ"); đường đến VERIFIED chỉ test bằng dữ liệu giả.
- **GĐ8 Thông báo (2026-10-12)**: `lib/features/notifications/{data/{notification_models,notification_repository},providers/notification_providers,widgets/notification_bell}.dart`; `lib/features/home/screens/notification_screen.dart` viết lại (lọc Tất cả/Chưa đọc, đọc tất cả, xoá bằng nút × hoặc vuốt, cập nhật ngay + hoàn lại khi lỗi, phân trang). Chuông `NotificationBell` thay chấm cam cứng ở `home_screen.dart` (CHỈ phần chuông): số chưa đọc, hỏi lại mỗi 60s + khi quay lại app + khi về từ màn thông báo; lỗi mạng thì không hiện số. Điều hướng theo `data.entityType` của backend (`AppNotification.route`): ORDER/DELIVERY/PAYMENT→đơn, DEBT_ENTRY→`/debt/:id`, CREDIT_PROFILE/PAYMENT trả nợ→`/debt`, SALES_RETURN→`/returns/:id`, REFUND→đơn, DIAGNOSIS_CASE→`/ai-scan/case/:id`. Đã xoá `models/notification.dart`, `mock_notifications.dart`. `notification_settings_screen` (bật/tắt loại thông báo) vẫn là mock: backend chưa có API cài đặt. Test: `test/features/notifications` (35), `test/live/notifications_live_test.dart` (6; đã thấy thông báo ORDER_STATUS_CHANGED thật do worker sinh ra sau khi huỷ đơn), `test/visual/notifications_screenshots_test.dart`. Lưu ý: backend gửi cả thông báo "Đã có kết quả AI chẩn đoán" (AI_DIAGNOSIS_COMPLETED) cho nông dân dù kết quả AI không được hiển thị.
- **GĐ9 Hoàn thiện (2026-10-12)**: xoá toàn bộ mock + màn/model cũ; `lib/core/network/api_call.dart` (`apiCall`: mọi repository đổi lỗi thành `ApiException` tiếng Việt; `detail` tiếng Anh của backend chỉ hiện nếu có ký tự không-ASCII); Trang chủ dữ liệu thật (`home_providers.dart`: thẻ chẩn đoán/đơn/nợ, kéo làm mới, `invalidateOrders/invalidateDiagnoses` làm mới cả Home); `/profile/sessions` (phiên đăng nhập, thu hồi từng phiên); `ComingSoonScreen` cho tính năng chưa có API; `NotFoundScreen`; `MissingConfigApp` (bản release thiếu `API_BASE_URL`); gỡ 8 dependency thừa, thêm `integration_test`; manifest: nhãn AgriSage, `allowBackup=false`. Sửa từ review: `isLoadingMore` reset ở `_loadFirst`, `AlwaysScrollableScrollPhysics` ở màn nợ, `ReturnLineRequest.allocate` từ chối nguồn không có mã, `cacheKey` ảnh chẩn đoán, màn xác nhận đặt hàng xoá snackbar cũ (che ô tick). Test: `test/visual/text_scale_test.dart` (x1.3/x1.6 ở 360px, 62 case), E2E `integration_test/app_flow_test.dart` (chạy `flutter drive --driver=test_driver/integration_test.dart --target=integration_test/app_flow_test.dart -d emulator-5554`, Gradle cần `ORG_GRADLE_PROJECT_android.aapt2FromMavenOverride=<sdk>/build-tools/36.1.0/aapt2.exe`; ảnh ra `build/e2e_shots`).
- **Test**: ~326 test thường pass, live tests (backend thật) pass: `test/live/{auth,profile,catalog,orders}_live_test.dart`; ảnh chụp font thật 390px & 320px: `test/visual/auth_screenshots_test.dart`.

## 4. IN PROGRESS
- Không có việc dở. `flutter analyze` sạch; `flutter test` 614 pass, 316 skip (live/ảnh chụp cần cờ môi trường). E2E emulator pass.

## 5. TODO (ưu tiên)
5. (Không còn việc theo kế hoạch.) Việc sau này: chờ Backend có API bài viết/đánh giá/cài đặt thông báo/FCM/avatar, cấu hình payOS/SMTP, tài khoản test có hạn mức.
6. Badge công nợ ở AppShell đã có (hasOverdueDebtProvider); danh sách phiên đăng nhập đã có (`/profile/sessions`).

## 6. FILES CHANGED (tóm tắt theo nhóm; đều chưa commit)
**Mới (untracked)**
- `lib/core/config/app_config.dart` – base URL/timeout/`orderSource='FARMER_MOBILE'`.
- `lib/core/network/{api_exception,auth_interceptor,dio_client,json_utils,paged_result,token_storage}.dart` – hạ tầng mạng (xem GĐ0).
- `lib/core/auth/session_provider.dart` – `SessionState{status,user}`, `SessionUser`, `sessionProvider`.
- `lib/core/utils/money.dart` – `formatVnd`.
- `lib/features/auth/{data/auth_repository,data/auth_validators,providers/auth_controller,widgets/auth_widgets}.dart`.
- `lib/features/profile/{data/profile_repository,providers/profile_providers}.dart`.
- `lib/features/products/{data/catalog_models,data/catalog_repository,providers/catalog_providers,widgets/product_widgets}.dart` (chứa cả giỏ hàng).
- `lib/features/orders/{data/order_models,data/order_repository,providers/order_providers,widgets/order_widgets}.dart` (đơn, thanh toán, giao hàng, hạn mức).
- `lib/shared/widgets/{error_retry_widget}.dart` (mới); `empty_data_widget.dart`, `shimmer_loading_widget.dart` là file chưa commit CÓ SẴN của người dùng.
- `test/{core,features,helpers,live,visual}/…`.

**Sửa (tracked)**
- `lib/router/app_router.dart` – thêm `authRedirect` guard + `_SessionRefresh`, route `:id` cho sản phẩm, OTP query (`channel`,`to`), QR nhận `orderId`, kết quả nhận `orderId`.
- Màn auth (`login/register/forgot/reset/otp/splash`), profile (`profile/edit/change_password/address_list/address_form`), products (`product_list/product_detail/cart/order_confirm/order_list/order_detail`), payment (`qr_payment/payment_result`) – viết lại để dùng API thật.
- `lib/features/home/screens/home_screen.dart` – CHỈ phần lời chào dùng `sessionProvider` (file người dùng đang sửa dở; các thẻ còn lại vẫn mock).
- `lib/core/theme/app_theme.dart` – CHỈ thêm màu cho `chipTheme.labelStyle` + `secondaryLabelStyle` (file người dùng đang sửa dở).
- `lib/data/models/address.dart` – model mới theo backend. Đã xoá: `lib/data/mock/mock_addresses.dart`, `mock_orders.dart`, `lib/data/models/order.dart`.
- `android/app/src/main/AndroidManifest.xml` (INTERNET), `android/app/src/debug/AndroidManifest.xml` (cleartext), `pubspec.yaml/lock` (người dùng có thay đổi từ trước — UNCONFIRMED chi tiết).
- `test/widget_test.dart` – thay test mẫu hỏng bằng smoke test khởi động app.

## 7. NEXT FILES (không còn — GĐ9 đã xong)
- Không còn file nào cần làm theo kế hoạch.

## 8. API / DATABASE / DATA CONTRACT
Tất cả dưới `/api`; nông dân dùng `/me/*` (danh tính từ JWT). Danh sách trả `PagedResult{items,page,pageSize,totalCount,totalPages}` (pageSize tối đa 100). Lỗi RFC7807 `{title,status,detail,errors?,traceId}`.
- **Auth**: `POST auth/register{fullName,phoneNumber?,email?,password}`, `auth/login{identifier,password}` → `{accessToken,refreshToken,sessionId,user{id,fullName,phoneNumber,email,role}}`; `auth/refresh{refreshToken}`; `auth/logout`, `logout-all`, `sessions`, `DELETE sessions/{id}`; `auth/me`; `change-password{currentPassword,newPassword}` (401 = sai MK hiện tại; thành công huỷ mọi phiên); `forgot-password{identifier}` (202; 503 nếu chưa cấu hình SMTP/SMS); `reset-password{token(76 ký tự "{32hex}.{43}"),newPassword}`; `phone-verification/{request,confirm{code 6 số}}`; `email-verification/{request,confirm{token}}`.
- **Hồ sơ/địa chỉ**: `GET/PUT me/profile{fullName,dateOfBirth(yyyy-MM-dd),gender MALE|FEMALE|OTHER}`; `me/addresses` GET/POST, `PUT/DELETE {id}`, `POST {id}/set-default`; body `{recipientName,recipientPhone,addressLine,province,addressType HOME|FARM|OTHER,ward?,district?,isDefault}`.
- **Catalog (công khai)**: `catalog/categories`, `catalog/products?page&pageSize&categoryId&search(≤100)`, `catalog/products/{storeProductId}` (packagings có `price` null nếu không bán/chưa giá).
- **Giỏ**: `GET me/cart`, `POST me/cart/items{storeProductId,productPackagingId,quantity}` (cộng dồn), `PUT items/{id}{quantity}` (thay), `DELETE items/{id}`, `DELETE me/cart`. Response `{id|null,items[{id,…,quantity,unitPrice?,lineTotalAmount?,isAvailable,unavailableReason NOT_SELLABLE|NO_PRICE}],subtotalAmount}`.
- **Đơn**: `POST me/orders{source:"FARMER_MOBILE",settlementType FULL_PAYMENT|CREDIT,fulfillmentType DELIVERY|PICKUP,addressId (chỉ khi DELIVERY),note≤1000}`; `GET me/orders?status&page`; `GET me/orders/{id}`; `POST me/orders/{id}/cancel{reason?}` (chỉ `PENDING_CONFIRMATION`); `GET me/orders/{id}/deliveries`; `GET me/orders/{id}/payments` (`orderTotal,paidAmount,remainingToPay,payments[],refunds[]`).
- **Thanh toán**: `POST me/payments/payos{paymentContext ORDER_PAYMENT|DEBT_REPAYMENT,orderId?,amount?}` → `{paymentId,paymentNumber,amount,checkoutUrl,qrCode(VietQR string),expiresAt,status}`; `GET me/payments/{id}`; `POST payments/{id}/sync`; `POST me/payments/{id}/cancel`; `POST payments/{id}/simulate-paid` (chỉ server PayOS:Mode=Simulated, còn lại 404).
- **Hạn mức/công nợ (chưa nối UI)**: `GET me/credit` → `{status,creditLimit,paymentTermDays,outstandingReceivable,reservedCredit,availableCredit}` (404 nếu chưa cấp); `GET me/debt` → `{currentBalance,overdueAmount,openEntryCount,oldestDueDate,…}`; `GET me/debt-entries` (`status,overdueOnly,dueFrom,dueTo,page`) item `{id,entryNumber,orderNumber,originalAmount,totalPaid,outstandingAmount,dueDate,isOverdue,overdueDays,status}`; `GET me/debt-entries/{id}` (có `orders`, `actions`, `transactions`, `payments`); `POST …/dispute{reason}`; `GET me/debt/allocation-preview?amount` → `{amount,allocations[{debtEntryId,entryNumber,dueDate,outstandingAmount,allocatedAmount}],unallocatedAmount}`. Phân bổ trả nợ: khoản đến hạn sớm nhất trước.
- **Chưa có API**: bài viết, đánh giá sản phẩm, push/FCM, upload avatar, đổi SĐT/email, tra payment theo `orderCode`.
- **Enum quan trọng**: Order status `PENDING_CONFIRMATION, CONFIRMED, PREPARING, READY_FOR_FULFILLMENT, PARTIALLY_FULFILLED, COMPLETED, CANCELLED, PARTIALLY_CANCELLED`; Payment `PENDING, PAID, FAILED, CANCELLED, PARTIALLY_REFUNDED, REFUNDED`; Delivery `ASSIGNED, OUT_FOR_DELIVERY, PARTIALLY_DELIVERED, RETRY_PENDING, DELIVERED, CANCELLED`; attempt `IN_PROGRESS, SUCCESS, PARTIAL_SUCCESS, FAILED, CANCELLED`.

## 9. BUSINESS RULES (đã chốt, theo backend)
- Giỏ không lưu giá; giá server tính lại mỗi lần; giỏ không giữ hàng; có dòng `isAvailable=false` thì không đặt được (phải xoá).
- Đặt hàng lấy hàng từ giỏ; thành công thì giỏ đóng (giỏ rỗng). DELIVERY cần đúng một `addressId`; PICKUP không gửi địa chỉ. Đơn lưu snapshot địa chỉ/giá.
- Chỉ huỷ online khi `PENDING_CONFIRMATION`; huỷ đơn đã trả → backend tạo yêu cầu hoàn tiền, cửa hàng hoàn thủ công.
- Đơn trả ngay + giao tận nơi: cửa hàng chỉ xác nhận khi đã nhận đủ tiền → app tự mở màn thanh toán sau khi đặt.
- Tiền chỉ tính đã trả khi server báo `PAID` (không tin returnUrl); mỗi đơn chỉ một link payOS chờ (link mới huỷ link cũ); số tiền payOS là số nguyên VND; hạn link 30 phút.
- Mua ghi nợ cần hồ sơ tín dụng ACTIVE, không nợ quá hạn, hạn mức còn đủ, đủ tồn kho; nếu không → 422 (app map tiếng Việt theo nội dung `detail`).
- Địa chỉ đầu tiên tự mặc định; chỉ một mặc định; sửa với `isDefault=false` không bỏ cờ mặc định; xoá mặc định → không còn mặc định; tối đa 10.
- Đổi mật khẩu → mọi phiên bị huỷ. Phone/email verification không bắt buộc cho chức năng nào.
- Rate limit: auth 10 req/phút/IP (429), catalog 120/phút/IP, upload 30/phút.
- App chỉ nhận tài khoản role `FARMER`.

## 10. DECISIONS
- Riverpod không codegen; mỗi feature có repository riêng, `ApiException` thống nhất; thông báo lỗi tiếng Việt do repository override theo status (backend `detail` tiếng Anh).
- Router guard thay vì listener; auth routes `/`, `/onboarding`, `/welcome`, `/login`, `/register`, `/forgot-password`, `/reset-password`; chưa đăng nhập vào route khác → `/welcome`.
- OTP là một ô nhập (không phải 6 ô).
- Tìm kiếm debounce 400ms; polling thanh toán 3s, sync sau 60s; mốc chờ đo bằng số nhịp (không dùng đồng hồ thật).
- Nút "[DEV] Giả lập đã thanh toán" chỉ hiện ở `kDebugMode`.
- Test: dùng fake repository + `AppHarness` (`test/helpers/app_harness.dart`); live test bật bằng `LIVE_API=1`; ảnh chụp bằng `SCREENSHOTS=1 FLUTTER_ROOT=/d/Develop/flutter flutter test --update-goldens test/visual/…` rồi xem ảnh và XOÁ `test/visual/shots`.

## 11. BLOCKERS / OPEN QUESTIONS
- **payOS chưa cấu hình trên server dev** (tạo link trả 503) → chưa test được thanh toán thật (QR, webhook, sync, hoàn tiền). Cần team Backend cấu hình `PayOS:ClientId/ApiKey/ChecksumKey` (hoặc bật `PayOS:Mode=Simulated`). Ảnh hưởng GĐ4 (đã làm bằng fake) và GĐ5 (trả nợ qua payOS).
- **Tài khoản test chưa có hồ sơ tín dụng** (`GET me/credit` → 404) → chưa test được mua ghi nợ thành công và toàn bộ công nợ có dữ liệu. Cần cửa hàng/Backend cấp hạn mức + tạo khoản nợ cho một tài khoản test. Ảnh hưởng GĐ4 (mua ghi nợ) và GĐ5.
- **SMTP/SMS chưa cấu hình** → forgot-password và xác minh SĐT/email trả 503 (luồng nhận mã thật chưa kiểm tra).
- **Deep link quay lại app sau payOS**: backend `PayOS:ReturnUrl` là URL web (`localhost:5174`); app dùng polling thay vì deep link. Có cần deep link hay không: UNCONFIRMED (cần quyết định Product/Backend).
- Backend không có mã lỗi riêng cho từ chối mua ghi nợ → app đoán theo chuỗi `detail` tiếng Anh (dễ vỡ nếu backend đổi câu chữ). Đề nghị backend trả mã lỗi: UNCONFIRMED đã gửi.

## 12. ERRORS / KNOWN ISSUES
- Doc backend (`docs/reference/api-flows/FE_GUIDE_*`) lỗi thời: ví dụ nói thêm quy cách chưa có giá vào giỏ → 422, nhưng code thật vẫn cho thêm dưới dạng dòng `NO_PRICE`. Tin code + live test.
- Catalog không trả tồn kho; giá catalog (bảng giá walk-in) có thể khác giá trong giỏ (bảng giá theo nhóm khách) → giỏ là giá chính thức.
- Máy dev: không có Visual Studio (không build Windows), không có chromedriver; Chrome web cần `--web-port=5173` để khớp CORS backend. Đã chạy E2E trên emulator Pixel_7 (Android); chưa thử trên máy Android thật.
- Đừng thử lại: heredoc bash chứa dấu `'` lồng (hay lỗi) → dùng công cụ Write/Edit; Python không có trên máy (dùng perl/sed hoặc Edit); GUID toàn số 0 gây 400 (validator) → dùng GUID hợp lệ ngẫu nhiên khi test 404; `pumpAndSettle` treo ở màn có spinner/timer vô hạn (QR payment, shimmer) → dùng `pump`; `router.location` không phản ánh route được `push` → kiểm tra bằng `find.byType`.
- Dữ liệu test thật đã tạo trong DB dev dùng chung, KHÔNG xoá được (không có API xoá): nhiều tài khoản "TEST Mobile Auth/Profile/Cart/Orders …" và vài đơn hàng (đã huỷ). Không tạo thêm nếu không cần.

## 13. DO NOT CHANGE
- Business rule ở mục 9 và API contract ở mục 8 (theo backend, không đổi phía app).
- Code ngoài scope; đặc biệt các file người dùng đang sửa dở: `app_theme.dart` (chỉ đã thêm màu chip), `home_screen.dart` (chỉ lời chào), `pubspec.yaml/lock`, `empty_data_widget.dart`, `shimmer_loading_widget.dart`.
- UI hiện có được người dùng chấp nhận (đã xem ảnh chụp): giữ phong cách (AppColors/AppTextStyles, thẻ bo góc, nút xanh `primary`).
- Quy ước: tên file/provider theo mẫu hiện có; thông báo người dùng bằng tiếng Việt; không commit/push/branch nếu chưa được yêu cầu.

## 14. ASSUMPTIONS (chưa xác nhận chính thức)
- Backend dev tại `localhost:5206` do người dùng tự chạy; không có URL deploy.
- Giá trong giỏ là giá chính thức khi đặt hàng.
- Role `FARMER` có đủ permission mặc định cho mọi route `/me/*`.
- Mua ghi nợ tạo khoản nợ khi cửa hàng giao hàng (theo mô tả backend) — UNCONFIRMED bằng test thực tế.

## 15. GIT STATUS
- Branch: `main`, HEAD `b92551f` (GĐ0–4 người dùng đã commit). GĐ5–9 CHƯA commit: nhiều file sửa (M), xoá (D: `lib/data/mock/*`, `lib/data/models/*`, các màn mock) và file/thư mục mới (untracked: `integration_test/`, `test_driver/`, `lib/features/{ai_doctor,debt,returns,notifications}/…`, test mới). Không commit/push/branch/reset khi chưa được yêu cầu.
- **Xung đột cần báo**: nhánh remote `origin/feature/mobile-diagnosis` (đồng đội) cũng làm màn chẩn đoán AI cũ; khi merge sẽ xung đột với GĐ7 (đã xoá các màn `ai_analyzing`, `diagnose_result`...). Cần thống nhất với đồng đội trước khi push.

## 16. CONTINUE FROM HERE
**Task**: GĐ0–9 đã xong; chờ người dùng review rồi tự commit/push.
Trước khi push cần người dùng quyết định: (1) xung đột với `origin/feature/mobile-diagnosis`; (2) `applicationId` vẫn `com.example.*` và bản release ký bằng debug key; (3) chưa có workflow CI trên main; (4) điều khoản "AI học từ ảnh" trong màn Chính sách chưa được xác nhận bởi Backend/pháp lý; (5) font tải lúc chạy qua `google_fonts` (offline dùng font hệ thống); (6) thông báo "Đã có kết quả AI chẩn đoán" (AI_DIAGNOSIS_COMPLETED) làm lộ khái niệm AI dù nông dân không thấy kết quả AI.
**Chỉ test bằng fake (chưa thấy trên server thật)**: công nợ có dữ liệu, trả hàng được duyệt, ca chẩn đoán VERIFIED, payOS thật, mua ghi nợ thành công.
**Giữ nguyên**: mục 9, 13. **Blocker**: mục 11.

## 17. QUICK RECOVERY SUMMARY
Flutter app nông dân AgriSage đã nối API backend ASP.NET (local :5206) cho mọi tính năng có API: auth, hồ sơ/địa chỉ, catalog/giỏ, đơn hàng + payOS, công nợ, trả hàng, chẩn đoán (chờ chuyên gia), thông báo, danh sách phiên đăng nhập. Không còn mock; tính năng chưa có API (bài viết, đánh giá, cài đặt thông báo, FCM, avatar) hiện "Sắp ra mắt" hoặc bị bỏ. GĐ9 (2026-10-12): xoá mock/màn cứng, Trang chủ dùng dữ liệu thật, helper `apiCall`, sửa lỗi từ review (isLoadingMore, invalidate Home, cuộn kéo-làm-mới), quét chữ cỡ lớn x1.3/x1.6 tại 360px (3 lỗi tràn đã sửa), E2E trên emulator Pixel_7 (`flutter drive`, 25 ảnh) pass. `flutter analyze` sạch, `flutter test` 614 pass (316 skip = live/ảnh chụp). Chưa commit GĐ5–9; không commit khi chưa được yêu cầu.
