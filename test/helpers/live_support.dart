import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

/// Chỉ chạy test tích hợp khi đặt LIVE_API=1.
final liveEnabled = Platform.environment['LIVE_API'] == '1';
final liveBaseUrl =
    Platform.environment['LIVE_API_URL'] ?? 'http://localhost:5206';

/// Backend giới hạn 10 request/phút cho các route đăng nhập/đăng ký/làm mới
/// token (429). Adapter này giữ tối đa 8 lần/phút bằng cách chờ khi cần.
class ThrottlingAdapter implements HttpClientAdapter {
  final _inner = IOHttpClientAdapter();
  final _stamps = <DateTime>[];

  static bool _limited(String path) =>
      path.startsWith('/api/auth/') &&
      !path.endsWith('/me') &&
      !path.endsWith('/logout') &&
      !path.endsWith('/logout-all') &&
      !path.contains('/sessions') &&
      !path.endsWith('/change-password');

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    if (_limited(options.path)) {
      const window = Duration(seconds: 61);
      final now = DateTime.now();
      _stamps.removeWhere((t) => now.difference(t) > window);
      if (_stamps.length >= 8) {
        await Future<void>.delayed(window - now.difference(_stamps.first));
        _stamps.removeWhere((t) => DateTime.now().difference(t) > window);
      }
      _stamps.add(DateTime.now());
    }
    return _inner.fetch(options, requestStream, cancelFuture);
  }

  @override
  void close({bool force = false}) => _inner.close(force: force);
}

final liveAdapter = ThrottlingAdapter();

/// Dio trần (không interceptor) dùng adapter điều tốc.
Dio rawLiveDio() =>
    Dio(BaseOptions(baseUrl: liveBaseUrl))..httpClientAdapter = liveAdapter;

String randomPhone() {
  final r = Random.secure();
  return '09${List.generate(8, (_) => r.nextInt(10)).join()}';
}
