import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/widgets.dart';
import 'package:signalr_netcore/signalr_client.dart';

import '../auth/session_provider.dart';
import '../config/app_config.dart';
import 'auth_interceptor.dart';
import 'dio_client.dart';

/// One authenticated socket per signed-in identity; events only invalidate existing REST snapshots.
final realtimeEventsProvider = StreamProvider.autoDispose<String>((ref) {
  final identity =
      ref.watch(sessionProvider.select((s) => (s.isAuthenticated, s.user?.id)));
  if (!identity.$1) return const Stream.empty();
  final stream = StreamController<String>();
  final storage = ref.read(tokenStorageProvider);
  final dio = ref.read(dioProvider);
  var disposed = false;
  var attempt = 0;
  Timer? retry;
  Timer? batch;
  final pending = <String>{};
  final seen = <String>{};
  const allowed = {
    'notifications',
    'permissions',
    'inventory',
    'diagnosis',
    'resync'
  };

  void emit(String topic) {
    if (disposed || !allowed.contains(topic)) return;
    pending.add(topic);
    batch ??= Timer(const Duration(milliseconds: 150), () {
      batch = null;
      final topics = pending.contains('resync') ? ['resync'] : pending.toList();
      pending.clear();
      if (!disposed) {
        for (final topic in topics) {
          stream.add(topic);
        }
      }
    });
  }

  final hub = HubConnectionBuilder()
      .withUrl('${AppConfig.apiBaseUrl}/api/realtime',
          options: HttpConnectionOptions(
            transport: HttpTransportType.WebSockets,
            requestTimeout: 15000,
            accessTokenFactory: () async {
              var tokens = await storage.read();
              final expiry = tokens == null
                  ? null
                  : AuthInterceptor.jwtExpiry(tokens.accessToken);
              if (tokens == null) throw StateError('No authenticated session');
              if (expiry != null &&
                  expiry.isBefore(
                      DateTime.now().add(const Duration(seconds: 30)))) {
                // Reuse the existing serialized refresh-token interceptor, never rotate tokens independently.
                await dio.get<dynamic>('/api/auth/me');
                tokens = await storage.read();
              }
              return tokens?.accessToken ?? '';
            },
          ))
      .withAutomaticReconnect(
          retryDelays: [1000, 2000, 5000, 10000, 30000]).build();

  Future<void> connect() async {
    if (disposed) return;
    try {
      await hub.start();
      if (disposed) {
        await hub.stop();
        return;
      }
      attempt = 0;
      emit('resync');
    } catch (_) {
      if (!disposed) {
        retry = Timer(Duration(seconds: min(30, 1 << min(attempt++, 5))), () {
          unawaited(connect());
        });
      }
    }
  }

  hub.on('Changed', (arguments) {
    if (arguments == null || arguments.isEmpty || arguments.first is! Map) {
      return;
    }
    final message = arguments.first as Map;
    final id = message['eventId'];
    final topic = message['topic'];
    if (id is! String ||
        topic is! String ||
        !allowed.contains(topic) ||
        !seen.add(id)) {
      return;
    }
    if (seen.length > 512) seen.remove(seen.first);
    emit(topic);
  });
  hub.onreconnected(({connectionId}) => emit('resync'));
  hub.onclose(({error}) {
    if (!disposed) {
      emit('resync');
      unawaited(connect());
    }
  });
  final lifecycle = AppLifecycleListener(onResume: () => emit('resync'));
  ref.onDispose(() {
    disposed = true;
    lifecycle.dispose();
    retry?.cancel();
    batch?.cancel();
    unawaited(hub.stop().catchError((Object _) {}));
    unawaited(stream.close());
  });
  unawaited(connect());
  return stream.stream;
});
