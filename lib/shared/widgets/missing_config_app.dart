import 'package:flutter/material.dart';

/// Hiện thay cho app khi một bản release được build mà quên `API_BASE_URL`.
/// Dành cho người build, không phải người dùng cuối.
class MissingConfigApp extends StatelessWidget {
  const MissingConfigApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.settings_suggest_outlined, size: 56),
                SizedBox(height: 16),
                Text(
                  'Ứng dụng chưa được cấu hình máy chủ.',
                  key: Key('missing_config_title'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'Bản này cần được build với --dart-define=API_BASE_URL=https://<địa-chỉ-máy-chủ>.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
