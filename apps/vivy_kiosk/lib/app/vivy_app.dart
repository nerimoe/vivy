import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/platform/kiosk_platform.dart';
import '../core/theme/theme_controller.dart';
import '../core/theme/vivy_theme.dart';
import '../features/alarms/application/alarm_controller.dart';
import '../features/kiosk/presentation/kiosk_screen.dart';
import '../features/recording/data/camera_segment_recorder.dart';
import '../features/recording/application/recording_settings.dart';

class VivyApp extends ConsumerWidget {
  const VivyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(platformBootstrapProvider);
    ref.watch(recordingBootstrapProvider);
    ref.watch(recordingSettingsProvider);
    ref.listen(recordingSettingsProvider, (_, next) {
      next.whenData(
        (settings) => ref
            .read(recordingServiceProvider)
            .setMaxCacheBytes(settings.maxCacheBytes),
      );
    });
    ref.watch(alarmsProvider);
    ref.listen(ambientLuxProvider, (_, next) {
      next.whenData(ref.read(themeControllerProvider.notifier).updateLux);
    });
    final theme = ref.watch(themeControllerProvider);
    return MaterialApp(
      title: 'Vivy',
      debugShowCheckedModeBanner: false,
      theme: VivyTheme.light(theme.palette),
      darkTheme: VivyTheme.dark(theme.palette),
      themeMode: theme.brightness == Brightness.dark
          ? ThemeMode.dark
          : ThemeMode.light,
      themeAnimationCurve: Curves.easeOutCubic,
      themeAnimationDuration: const Duration(milliseconds: 600),
      home: const KioskScreen(),
    );
  }
}
