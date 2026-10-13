# Thử WebView thanh toán payOS (không cần khoá payOS)

Chế độ giả lập của backend không mở WebView, nên các đường đi quan trọng của WebView (chặn link trả về/huỷ,
mở app ngân hàng) cần một trang thử riêng. (Công cụ của nhánh feature/mobile-diagnosis.)

1. Phục vụ thư mục này ở cổng 8099, ví dụ: `python -m http.server 8099 --bind 0.0.0.0`
   (hoặc `npx http-server -p 8099 -a 0.0.0.0`).
2. Chạy app với `--dart-define-from-file=env/emulator.json` (có `SHOW_DEV_TOOLS=true`).
3. Tài khoản → mục "Công cụ phát triển" → "Thử WebView payOS".
4. Bấm lần lượt từng liên kết và đối chiếu với mô tả trên trang:
   - 1 (link trả về ghi `status=PAID`): app KHÔNG tin link mà hỏi server; mã thử không tồn tại nên báo lỗi, không báo thành công.
   - 2 (huỷ): sang màn "Bạn đã hủy thanh toán".
   - 3 (`intent://` chưa cài app): mở trang dự phòng trong WebView.
   - 4 (scheme riêng chưa cài app): báo "Không mở được ứng dụng ngân hàng".
   - Nút Back: lùi trang trong WebView; ở trang đầu thì hỏi có rời trang thanh toán không.

Emulator gọi máy chủ qua `10.0.2.2`; điện thoại thật cần `adb reverse tcp:8099 tcp:8099` và `env/device.json`.
