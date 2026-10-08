# Thử WebView thanh toán payOS (không cần khóa payOS)

Chế độ giả lập của backend không bao giờ mở WebView, nên các đường đi quan trọng của WebView (chặn link trả về/hủy,
mở app ngân hàng) cần một trang thử riêng.

1. Trong thư mục này chạy: `python -m http.server 8099 --bind 0.0.0.0`
2. Chạy app với `--dart-define-from-file=env/emulator.json` (có `SHOW_DEV_TOOLS=true`).
3. Tài khoản → mục "Công cụ phát triển" → "Thử WebView payOS".
4. Bấm lần lượt từng liên kết và đối chiếu với mô tả trên trang.

Emulator gọi máy chủ qua `10.0.2.2`; điện thoại thật cần `adb reverse tcp:8099 tcp:8099` và địa chỉ `127.0.0.1`.
