// Renders assets/images/logo.svg into the Android launcher icons (res/mipmap-*/ic_launcher.png).
//
// Run it from the project root whenever the logo changes:
//   flutter test tool/make_launcher_icons.dart
//
// It is a "test" only because that is the way to get Flutter's renderer without a device. It lives outside test/ so
// `flutter test` does not run it with the suite.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

const _sizes = {
  'mdpi': 48,
  'hdpi': 72,
  'xhdpi': 96,
  'xxhdpi': 144,
  'xxxhdpi': 192,
};

void main() {
  testWidgets('render the launcher icons', (tester) async {
    for (final entry in _sizes.entries) {
      final key = GlobalKey();
      final size = entry.value.toDouble();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: RepaintBoundary(
              key: key,
              child: SizedBox(width: size, height: size, child: SvgPicture.asset('assets/images/logo.svg', width: size, height: size)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.runAsync(() async {
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
        final file = File('android/app/src/main/res/mipmap-${entry.key}/ic_launcher.png');
        await file.writeAsBytes(bytes.buffer.asUint8List());
        // ignore: avoid_print
        print('${file.path}: ${image.width}x${image.height}');
      });
    }
  });
}
