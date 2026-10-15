import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// Driver của `integration_test/app_flow_test.dart`: lưu ảnh chụp màn hình thiết bị
/// vào `build/e2e_shots/`.
Future<void> main() async {
  await integrationDriver(
    onScreenshot: (String name, List<int> bytes, [Map<String, Object?>? args]) async {
      final file = File('build/e2e_shots/$name.png')..createSync(recursive: true);
      file.writeAsBytesSync(bytes);
      return true;
    },
  );
}
