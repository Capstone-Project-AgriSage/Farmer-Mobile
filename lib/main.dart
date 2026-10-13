import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/config/app_config.dart';
import 'shared/widgets/missing_config_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (!AppConfig.isConfigured) {
    runApp(const MissingConfigApp());
    return;
  }
  runApp(
    const ProviderScope(
      child: AgriSageApp(),
    ),
  );
}
