import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/vivy_theme.dart';
import '../../../core/motion/clock_motion_spring.dart';
import '../../../core/platform/kiosk_platform.dart';
import '../../alarms/application/alarm_controller.dart';
import '../../alarms/domain/alarm.dart';
import '../../../core/platform/location_service.dart';
import '../../daemon/data/daemon_client.dart';
import '../../recording/application/recording_settings.dart';
import '../../recording/data/camera_segment_recorder.dart';
import '../../weather/data/weather_forecast.dart';
import '../application/kiosk_controller.dart';
import '../domain/kiosk_models.dart';
import 'date_labels.dart';

class KioskScreen extends ConsumerStatefulWidget {
  const KioskScreen({super.key});

  @override
  ConsumerState<KioskScreen> createState() => _KioskScreenState();
}

class _KioskScreenState extends ConsumerState<KioskScreen> {
  Timer? _chromeTimer;
  bool _chromeVisible = false;

  void _showChrome() {
    _chromeTimer?.cancel();
    if (!_chromeVisible) setState(() => _chromeVisible = true);
    _chromeTimer = Timer(const Duration(seconds: 8), () {
      if (mounted) setState(() => _chromeVisible = false);
    });
  }

  @override
  void dispose() {
    _chromeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = ref.watch(clockProvider).value ?? DateTime.now();
    final activeAlarm = ref.watch(activeAlarmProvider);
    if (activeAlarm != null) return _ActiveAlarmScreen(alarm: activeAlarm);
    final kiosk = ref.watch(kioskControllerProvider);
    final recordingRuntime = ref.watch(recordingBootstrapProvider);
    final recordingSettings = ref.watch(recordingSettingsProvider);
    final recordingCapacity = switch (recordingSettings) {
      AsyncData(value: final settings) => settings.maxCacheBytes,
      _ => 20 * 1024 * 1024 * 1024,
    };
    final recording = RecordingSummary(
      status: recordingRuntime.when(
        data: (service) =>
            service == null ? RecordingStatus.disabled : RecordingStatus.active,
        error: (_, _) => RecordingStatus.error,
        loading: () => RecordingStatus.recovering,
      ),
      usedBytes: kiosk.recording.usedBytes,
      capacityBytes: recordingCapacity,
      segmentMinutes: kiosk.recording.segmentMinutes,
    );
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 860;
    final weather = ref.watch(weatherForecastProvider);
    final desktopNotifications = ref.watch(desktopNotificationsProvider);
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final background = Color.alphaBlend(
      scheme.primary.withValues(alpha: dark ? 0.18 : 0.12),
      scheme.surfaceContainerLow,
    );

    return Scaffold(
      backgroundColor: background,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _showChrome,
        child: SafeArea(
          minimum: EdgeInsets.fromLTRB(
            compact ? 32 : 56,
            compact ? 16 : 28,
            compact ? 28 : 56,
            compact ? 16 : 28,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Center(child: _ClockFace(now: now)),
              Align(
                alignment: Alignment.bottomLeft,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: compact ? 32 : 0),
                  child: _InformationRail(
                    now: now,
                    recording: recording,
                    chromeVisible: _chromeVisible,
                    weather: weather,
                    desktopNotifications: desktopNotifications,
                    upcoming: kiosk.upcoming,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActiveAlarmScreen extends ConsumerWidget {
  const _ActiveAlarmScreen({required this.alarm});

  final VivyAlarm alarm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(alarmsProvider.notifier);
    return ColoredBox(
      color: Theme.of(context).colorScheme.error,
      child: SafeArea(
        minimum: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              DateFormat('HH:mm').format(DateTime.now()),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onError,
                fontSize: 34,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const Spacer(),
            Text(
              alarm.label,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onError,
                fontSize: 64,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onError,
                side: BorderSide(color: Theme.of(context).colorScheme.onError),
                minimumSize: const Size.fromHeight(56),
              ),
              onPressed: () => controller.snooze(alarm),
              icon: const Icon(Icons.snooze_rounded),
              label: Text('Snooze ${alarm.snoozeMinutes} minutes'),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.onError,
                foregroundColor: Theme.of(context).colorScheme.error,
                minimumSize: const Size.fromHeight(56),
              ),
              onPressed: () => controller.complete(alarm.id),
              icon: const Icon(Icons.check_rounded),
              label: const Text('Dismiss'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InformationRail extends StatelessWidget {
  const _InformationRail({
    required this.now,
    required this.recording,
    required this.chromeVisible,
    required this.weather,
    required this.desktopNotifications,
    required this.upcoming,
  });

  final DateTime now;
  final RecordingSummary recording;
  final bool chromeVisible;
  final AsyncValue<WeatherForecast?> weather;
  final AsyncValue<List<DesktopNotification>> desktopNotifications;
  final List<UpcomingItem> upcoming;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _DateDisplay(now: now),
          const SizedBox(width: 20),
          Expanded(
            child: _NotificationStatusArea(
              now: now,
              weather: weather,
              desktopNotifications: desktopNotifications,
              upcoming: upcoming,
            ),
          ),
          _StatusDock(recording: recording, chromeVisible: chromeVisible),
          _StatusSlot(
            visible: chromeVisible,
            child: IconButton(
              tooltip: 'Settings',
              onPressed: () => showVivyPanel(
                context,
                title: 'Settings',
                child: const _SettingsPanel(),
                landscapeWorkspace: true,
              ),
              icon: const Icon(Icons.tune_rounded, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateDisplay extends ConsumerWidget {
  const _DateDisplay({required this.now});

  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context);
    final appearance = ref.watch(themeControllerProvider);
    final dateColor = scheme.onSurfaceVariant;
    final weekdayColor = scheme.onSurfaceVariant.withValues(alpha: 0.72);
    return Semantics(
      label: DateFormat('EEEE, MMMM d').format(now),
      child: ExcludeSemantics(
        child: SizedBox(
          width: 180,
          height: 48,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  DateFormat('MM/dd').format(now),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: dateColor,
                    fontFamily: _clockTypefaceFamily(appearance.dateTypeface),
                    fontSize: 30,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  compactWeekdayLabel(locale, now.weekday),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: weekdayColor,
                    fontFamily: _clockTypefaceFamily(appearance.dateTypeface),
                    fontSize: 28,
                    height: 1,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationStatusArea extends StatefulWidget {
  const _NotificationStatusArea({
    required this.now,
    required this.weather,
    required this.desktopNotifications,
    required this.upcoming,
  });

  final DateTime now;
  final AsyncValue<WeatherForecast?> weather;
  final AsyncValue<List<DesktopNotification>> desktopNotifications;
  final List<UpcomingItem> upcoming;

  @override
  State<_NotificationStatusArea> createState() =>
      _NotificationStatusAreaState();
}

class _NotificationStatusAreaState extends State<_NotificationStatusArea> {
  Timer? _rotation;
  int _index = 0;
  List<NotificationStatusItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _syncItems();
  }

  @override
  void didUpdateWidget(covariant _NotificationStatusArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncItems();
  }

  void _syncItems() {
    final next = _notificationItems(
      now: widget.now,
      weather: widget.weather,
      desktopNotifications: widget.desktopNotifications,
      upcoming: widget.upcoming,
    );
    final changed =
        next.length != _items.length ||
        next.asMap().entries.any(
          (entry) =>
              entry.value.id != _items[entry.key].id ||
              entry.value.message != _items[entry.key].message,
        );
    if (!changed) return;
    final currentId = _items.isEmpty ? null : _items[_index].id;
    final retainedIndex = currentId == null
        ? -1
        : next.indexWhere((item) => item.id == currentId);
    _items = next;
    _index = retainedIndex >= 0 ? retainedIndex : 0;
    _rotation?.cancel();
    if (_items.length > 1) {
      _rotation = Timer.periodic(const Duration(seconds: 5), (_) {
        if (mounted) setState(() => _index = (_index + 1) % _items.length);
      });
    }
  }

  @override
  void dispose() {
    _rotation?.cancel();
    super.dispose();
  }

  void _advanceOrOpen() {
    if (_items.isEmpty) return;
    if (_items.length > 1) {
      setState(() => _index = (_index + 1) % _items.length);
      return;
    }
    _openNotification(_items.single);
  }

  void _openNotification(NotificationStatusItem item) {
    final scheme = Theme.of(context).colorScheme;
    switch (item.source) {
      case NotificationSource.weather:
        showVivyPanel(
          context,
          title: 'Weather notice',
          child: _MessagePanel(message: item.message, color: scheme.tertiary),
        );
      case NotificationSource.alarm:
      case NotificationSource.reminder:
        final reminder = widget.upcoming.where((entry) => entry.id == item.id);
        if (reminder.isNotEmpty) {
          showVivyPanel(
            context,
            title: reminder.first.title,
            child: _ReminderPanel(item: reminder.first),
          );
        }
      case NotificationSource.desktop:
        showVivyPanel(
          context,
          title: item.title ?? 'Notification',
          child: _MessagePanel(message: item.message, color: scheme.primary),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) return const SizedBox.shrink();
    final item = _items[_index];
    final scheme = Theme.of(context).colorScheme;
    final icon = _notificationIcon(item.source);
    final color = _notificationColor(scheme, item.source);
    return Semantics(
      button: true,
      label: item.message,
      hint: _items.length > 1
          ? 'Tap to show the next notification'
          : 'Tap for details',
      child: Tooltip(
        message: _items.length > 1
            ? '${item.message} · ${_index + 1}/${_items.length}'
            : item.message,
        child: InkResponse(
          radius: 28,
          onTap: _advanceOrOpen,
          child: SizedBox(
            height: 48,
            child: Row(
              children: [
                Icon(icon, size: 19, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    layoutBuilder: (currentChild, previousChildren) => Stack(
                      alignment: Alignment.centerLeft,
                      children: <Widget>[
                        ...previousChildren,
                        ...?currentChild == null
                            ? null
                            : <Widget>[currentChild],
                      ],
                    ),
                    child: Align(
                      key: ValueKey(item.id),
                      alignment: Alignment.centerLeft,
                      child: Text(
                        item.message,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                if (_items.length > 1) ...[
                  const SizedBox(width: 8),
                  Text(
                    '${_index + 1}/${_items.length}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

List<NotificationStatusItem> _notificationItems({
  required DateTime now,
  required AsyncValue<WeatherForecast?> weather,
  required AsyncValue<List<DesktopNotification>> desktopNotifications,
  required List<UpcomingItem> upcoming,
}) {
  final items = <NotificationStatusItem>[];
  final forecast = switch (weather) {
    AsyncData(value: final value) => value,
    _ => null,
  };
  final advisory = forecast?.advisory(now);
  if (advisory != null) {
    items.add(
      NotificationStatusItem(
        id: 'weather:${advisory.text}',
        source: NotificationSource.weather,
        message: advisory.text,
        priority: advisory.priority,
        createdAt: now,
      ),
    );
  }
  for (final item in approachingItems(upcoming, now)) {
    final source = item.kind == ReminderKind.alarm
        ? NotificationSource.alarm
        : NotificationSource.reminder;
    final due = DateFormat('HH:mm').format(item.dueAt);
    items.add(
      NotificationStatusItem(
        id: item.id,
        source: source,
        message: '${item.title} · $due',
        title: item.title,
        note: item.note,
        priority: switch (item.kind) {
          ReminderKind.alarm => 100,
          ReminderKind.calendar => 86,
          ReminderKind.task => 74,
        },
        createdAt: item.dueAt,
      ),
    );
  }
  final notifications = switch (desktopNotifications) {
    AsyncData(value: final value) => value,
    _ => const <DesktopNotification>[],
  };
  for (final notification in notifications) {
    final body = notification.body.trim();
    items.add(
      NotificationStatusItem(
        id: 'desktop:${notification.id}',
        source: NotificationSource.desktop,
        message: body.isEmpty
            ? notification.title
            : '${notification.title} · $body',
        title: notification.title,
        note: body.isEmpty ? null : body,
        priority: 92,
        createdAt: notification.createdAt,
      ),
    );
  }
  items.sort((a, b) {
    final priority = b.priority.compareTo(a.priority);
    return priority == 0 ? b.createdAt.compareTo(a.createdAt) : priority;
  });
  return items.take(4).toList(growable: false);
}

IconData _notificationIcon(NotificationSource source) => switch (source) {
  NotificationSource.weather => Icons.cloud_outlined,
  NotificationSource.alarm => Icons.alarm_rounded,
  NotificationSource.reminder => Icons.event_note_outlined,
  NotificationSource.desktop => Icons.notifications_none_rounded,
};

Color _notificationColor(ColorScheme scheme, NotificationSource source) =>
    switch (source) {
      NotificationSource.weather => scheme.tertiary,
      NotificationSource.alarm => scheme.error,
      NotificationSource.reminder => scheme.primary,
      NotificationSource.desktop => scheme.secondary,
    };

class _MessagePanel extends StatelessWidget {
  const _MessagePanel({required this.message, required this.color});

  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: Text(
        message,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ClockFace extends ConsumerStatefulWidget {
  const _ClockFace({required this.now});

  final DateTime now;

  @override
  ConsumerState<_ClockFace> createState() => _ClockFaceState();
}

class _ClockFaceState extends ConsumerState<_ClockFace>
    with SingleTickerProviderStateMixin {
  final ClockMotionSpring _motion = ClockMotionSpring();
  late final Ticker _ticker;
  Duration? _previousTick;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick);
  }

  void _onMotion(DeviceMotionSample sample) {
    _motion.addSample(sample);
    if (!_ticker.isActive && !_motion.isSettled) {
      _previousTick = null;
      _ticker.start();
    }
  }

  void _tick(Duration elapsed) {
    final previous = _previousTick;
    _previousTick = elapsed;
    if (previous == null) return;
    _motion.step((elapsed - previous).inMicroseconds / 1000000);
    if (mounted) setState(() {});
    if (_motion.isSettled) {
      _ticker.stop();
      _previousTick = null;
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(deviceMotionProvider, (_, next) => next.whenData(_onMotion));
    final appearance = ref.watch(themeControllerProvider);
    final scheme = Theme.of(context).colorScheme;
    final clockColor = switch (appearance.clockColorRole) {
      ClockColorRole.primary => scheme.primary,
      ClockColorRole.secondary => scheme.secondary,
      ClockColorRole.tertiary => scheme.tertiary,
      ClockColorRole.surface => scheme.onSurface,
    };
    final fontFamily = _clockTypefaceFamily(appearance.clockTypeface);
    final minuteSeed =
        widget.now.millisecondsSinceEpoch ~/ Duration.millisecondsPerMinute;
    final offset = Offset(
      ((minuteSeed % 5) - 2).toDouble(),
      (((minuteSeed ~/ 5) % 5) - 2).toDouble(),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        return Transform.translate(
          offset: _motion.position,
          child: AnimatedSlide(
            duration: const Duration(seconds: 2),
            curve: Curves.easeInOut,
            offset: Offset(
              offset.dx / math.max(constraints.maxWidth, 1),
              offset.dy / math.max(constraints.maxHeight, 1),
            ),
            child: Align(
              alignment: Alignment.center,
              child: Semantics(
                label: DateFormat('h mm a').format(widget.now),
                child: ExcludeSemantics(
                  child: SizedBox(
                    width: constraints.maxWidth * 0.96,
                    height: constraints.maxHeight * 0.78,
                    child: FittedBox(
                      fit: BoxFit.contain,
                      alignment: Alignment.center,
                      child: Transform.scale(
                        scaleY: 1.07,
                        alignment: Alignment.center,
                        child: Text(
                          DateFormat('HH:mm').format(widget.now),
                          maxLines: 1,
                          style: TextStyle(
                            color: clockColor,
                            fontFamily: fontFamily,
                            fontSize: 360,
                            height: 0.82,
                            fontWeight: _fontWeight(appearance.clockWeight),
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StatusDock extends ConsumerWidget {
  const _StatusDock({required this.recording, required this.chromeVisible});

  final RecordingSummary recording;
  final bool chromeVisible;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final androidVoice =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final daemon = ref.watch(daemonHealthProvider);
    final computerOnline = daemon.hasValue;
    final scheme = Theme.of(context).colorScheme;
    final showRecording =
        chromeVisible || recording.status != RecordingStatus.active;
    final showVoice = chromeVisible || !androidVoice;
    final showComputer = chromeVisible || !computerOnline;
    return SizedBox(
      height: 48,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: 4),
          _StatusSlot(
            visible: showRecording,
            child: Tooltip(
              message: 'Recording status',
              child: Semantics(
                button: true,
                label: 'Recording ${recording.status.name}',
                child: InkResponse(
                  radius: 24,
                  onTap: () => showVivyPanel(
                    context,
                    title: 'Recording',
                    child: _RecordingPanel(summary: recording),
                  ),
                  child: SizedBox.square(
                    dimension: 48,
                    child: Center(
                      child: _RecordingLight(status: recording.status),
                    ),
                  ),
                ),
              ),
            ),
          ),
          _StatusSlot(
            visible: showVoice,
            child: IconButton(
              tooltip: androidVoice
                  ? 'Voice assistant ready'
                  : 'Voice assistant unavailable',
              onPressed: () => showVivyPanel(
                context,
                title: 'Voice assistant',
                child: _VoicePanel(available: androidVoice),
              ),
              icon: Icon(
                androidVoice
                    ? Icons.graphic_eq_rounded
                    : Icons.mic_off_outlined,
                color: androidVoice
                    ? scheme.onSurfaceVariant.withValues(alpha: 0.76)
                    : scheme.tertiary.withValues(alpha: 0.66),
                size: 19,
              ),
            ),
          ),
          _StatusSlot(
            visible: showComputer,
            child: IconButton(
              tooltip: computerOnline
                  ? 'Home computer online'
                  : 'Computer offline',
              onPressed: null,
              icon: Icon(
                computerOnline
                    ? Icons.computer_rounded
                    : Icons.desktop_access_disabled_rounded,
                color: computerOnline
                    ? scheme.onSurfaceVariant.withValues(alpha: 0.7)
                    : scheme.tertiary.withValues(alpha: 0.66),
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _StatusSlot extends StatelessWidget {
  const _StatusSlot({required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: visible ? child : const SizedBox.shrink(),
    );
  }
}

class _RecordingLight extends StatelessWidget {
  const _RecordingLight({required this.status});

  final RecordingStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      RecordingStatus.active => VivyTheme.mint,
      RecordingStatus.recovering => Theme.of(
        context,
      ).colorScheme.secondary.withValues(alpha: 0.72),
      RecordingStatus.error => Theme.of(
        context,
      ).colorScheme.tertiary.withValues(alpha: 0.7),
      RecordingStatus.disabled => Theme.of(
        context,
      ).colorScheme.outline.withValues(alpha: 0.62),
    };
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      width: 11,
      height: 11,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: status == RecordingStatus.active
            ? [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 9)]
            : null,
      ),
    );
  }
}

class _ReminderPanel extends ConsumerWidget {
  const _ReminderPanel({required this.item});

  final UpcomingItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(DateFormat('EEEE, MMMM d · HH:mm').format(item.dueAt)),
        if (item.note case final note?) ...[
          const SizedBox(height: 12),
          Text(note, style: Theme.of(context).textTheme.titleMedium),
        ],
        const Spacer(),
        OutlinedButton.icon(
          onPressed: () {
            ref.read(kioskControllerProvider.notifier).snooze(item.id);
            Navigator.of(context).pop();
          },
          icon: const Icon(Icons.snooze_rounded),
          label: const Text('Snooze 10 minutes'),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: () {
            ref.read(kioskControllerProvider.notifier).complete(item.id);
            Navigator.of(context).pop();
          },
          icon: const Icon(Icons.check_rounded),
          label: const Text('Complete'),
        ),
      ],
    );
  }
}

class _RecordingPanel extends StatelessWidget {
  const _RecordingPanel({required this.summary});

  final RecordingSummary summary;

  @override
  Widget build(BuildContext context) {
    final usedGb = summary.usedBytes / (1024 * 1024 * 1024);
    final capacityGb = summary.capacityBytes / (1024 * 1024 * 1024);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainer,
            child: const Center(child: Icon(Icons.videocam_outlined, size: 42)),
          ),
        ),
        const SizedBox(height: 24),
        _DetailLine(label: 'State', value: summary.status.name),
        _DetailLine(
          label: 'Segments',
          value: '${summary.segmentMinutes} minutes',
        ),
        _DetailLine(
          label: 'Storage',
          value:
              '${usedGb.toStringAsFixed(1)} / ${capacityGb.toStringAsFixed(0)} GB',
        ),
        const SizedBox(height: 12),
        LinearProgressIndicator(
          value: summary.usedBytes / summary.capacityBytes,
        ),
      ],
    );
  }
}

class _VoicePanel extends StatelessWidget {
  const _VoicePanel({required this.available});

  final bool available;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          available ? Icons.graphic_eq_rounded : Icons.mic_off_outlined,
          size: 42,
          color: available
              ? VivyTheme.mint
              : Theme.of(context).colorScheme.outline,
        ),
        const SizedBox(height: 18),
        Text(
          available
              ? 'Ready on this device'
              : 'Available on Android Kiosk only',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 10),
        Text(
          available
              ? 'Listening starts after the local wake word is detected.'
              : 'The web Kiosk does not store voice credentials or continuously capture audio.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ],
    );
  }
}

class _SettingsPanel extends ConsumerWidget {
  const _SettingsPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(themeControllerProvider);
    final controller = ref.read(themeControllerProvider.notifier);
    final scheme = Theme.of(context).colorScheme;
    final size = MediaQuery.sizeOf(context);
    if (size.width > size.height && size.height < 500) {
      return _LandscapeSettingsPanel(
        state: state,
        controller: controller,
        scheme: scheme,
      );
    }
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Text('Brightness', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 14),
        SegmentedButton<VivyThemeMode>(
          segments: const [
            ButtonSegment(
              value: VivyThemeMode.automatic,
              icon: Icon(Icons.brightness_auto_rounded),
              label: Text('Auto'),
            ),
            ButtonSegment(
              value: VivyThemeMode.light,
              icon: Icon(Icons.light_mode_outlined),
              label: Text('Light'),
            ),
            ButtonSegment(
              value: VivyThemeMode.dark,
              icon: Icon(Icons.dark_mode_outlined),
              label: Text('Dark'),
            ),
          ],
          selected: {state.mode},
          onSelectionChanged: (selection) {
            switch (selection.single) {
              case VivyThemeMode.automatic:
                controller.setAutomatic();
              case VivyThemeMode.light:
                controller.setTemporary(Brightness.light);
              case VivyThemeMode.dark:
                controller.setTemporary(Brightness.dark);
            }
          },
        ),
        const SizedBox(height: 28),
        Text(
          'Material palette',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: VivyPalette.values
              .map(
                (palette) => _ColorSwatchButton(
                  label: palette.name,
                  color: VivyTheme.paletteSeeds[palette]!,
                  selected: state.palette == palette,
                  onPressed: () => controller.setPalette(palette),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 28),
        Text('Clock type', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 14),
        _ClockTypefacePicker(
          selected: state.clockTypeface,
          weight: state.clockWeight,
          onSelected: controller.setClockTypeface,
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Text('Weight', style: Theme.of(context).textTheme.bodyLarge),
            const Spacer(),
            Text(
              '${state.clockWeight}',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        Slider(
          value: state.clockWeight.toDouble(),
          min: 100,
          max: 900,
          divisions: 8,
          onChanged: (value) => controller.setClockWeight(value.round()),
        ),
        const SizedBox(height: 28),
        Text('Date type', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 14),
        _ClockTypefacePicker(
          selected: state.dateTypeface,
          weight: 700,
          onSelected: controller.setDateTypeface,
          subject: 'date',
        ),
        const SizedBox(height: 28),
        Text('Clock color', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 14),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children:
              [
                    (ClockColorRole.primary, scheme.primary),
                    (ClockColorRole.secondary, scheme.secondary),
                    (ClockColorRole.tertiary, scheme.tertiary),
                    (ClockColorRole.surface, scheme.onSurface),
                  ]
                  .map(
                    (option) => _ColorSwatchButton(
                      label: option.$1.name,
                      color: option.$2,
                      selected: state.clockColorRole == option.$1,
                      onPressed: () => controller.setClockColorRole(option.$1),
                    ),
                  )
                  .toList(),
        ),
        const SizedBox(height: 28),
        const _RecordingCacheControl(),
        const SizedBox(height: 28),
        _DetailLine(label: 'Theme source', value: state.source.name),
        _DetailLine(
          label: 'Location',
          value: state.latitude == null
              ? 'Not configured'
              : '${state.latitude!.toStringAsFixed(2)}, ${state.longitude!.toStringAsFixed(2)}',
        ),
        if (state.latitude == null) ...[
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () async {
              try {
                final position = await LocationService().current();
                await controller.setLocation(
                  position.latitude,
                  position.longitude,
                );
              } on Exception catch (error) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(error.toString())));
              }
            },
            icon: const Icon(Icons.my_location_rounded),
            label: const Text('Use current area'),
          ),
        ],
      ],
    );
  }
}

class _LandscapeSettingsPanel extends ConsumerWidget {
  const _LandscapeSettingsPanel({
    required this.state,
    required this.controller,
    required this.scheme,
  });

  final ThemeState state;
  final ThemeController controller;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final titleStyle = Theme.of(
      context,
    ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(right: 18, bottom: 16),
            children: [
              Text('Brightness', style: titleStyle),
              const SizedBox(height: 8),
              SegmentedButton<VivyThemeMode>(
                segments: const [
                  ButtonSegment(
                    value: VivyThemeMode.automatic,
                    label: Text('Auto'),
                  ),
                  ButtonSegment(
                    value: VivyThemeMode.light,
                    label: Text('Light'),
                  ),
                  ButtonSegment(value: VivyThemeMode.dark, label: Text('Dark')),
                ],
                selected: {state.mode},
                onSelectionChanged: (selection) {
                  switch (selection.single) {
                    case VivyThemeMode.automatic:
                      controller.setAutomatic();
                    case VivyThemeMode.light:
                      controller.setTemporary(Brightness.light);
                    case VivyThemeMode.dark:
                      controller.setTemporary(Brightness.dark);
                  }
                },
              ),
              const SizedBox(height: 18),
              Text('Material palette', style: titleStyle),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: VivyPalette.values
                    .map(
                      (palette) => _ColorSwatchButton(
                        label: palette.name,
                        color: VivyTheme.paletteSeeds[palette]!,
                        selected: state.palette == palette,
                        onPressed: () => controller.setPalette(palette),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 18),
              Text('Clock color', style: titleStyle),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children:
                    [
                          (ClockColorRole.primary, scheme.primary),
                          (ClockColorRole.secondary, scheme.secondary),
                          (ClockColorRole.tertiary, scheme.tertiary),
                          (ClockColorRole.surface, scheme.onSurface),
                        ]
                        .map(
                          (option) => _ColorSwatchButton(
                            label: option.$1.name,
                            color: option.$2,
                            selected: state.clockColorRole == option.$1,
                            onPressed: () =>
                                controller.setClockColorRole(option.$1),
                          ),
                        )
                        .toList(),
              ),
              const SizedBox(height: 18),
              Text('Date type', style: titleStyle),
              const SizedBox(height: 8),
              _ClockTypefacePicker(
                selected: state.dateTypeface,
                weight: 700,
                onSelected: controller.setDateTypeface,
                compact: true,
                subject: 'date',
              ),
            ],
          ),
        ),
        VerticalDivider(color: scheme.outlineVariant, width: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(left: 18, bottom: 16),
            children: [
              Text('Clock type', style: titleStyle),
              const SizedBox(height: 8),
              _ClockTypefacePicker(
                selected: state.clockTypeface,
                weight: state.clockWeight,
                onSelected: controller.setClockTypeface,
                compact: true,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text('Weight', style: titleStyle),
                  const Spacer(),
                  Text(
                    '${state.clockWeight}',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              Slider(
                value: state.clockWeight.toDouble(),
                min: 100,
                max: 900,
                divisions: 8,
                onChanged: (value) => controller.setClockWeight(value.round()),
              ),
              const SizedBox(height: 8),
              const _RecordingCacheControl(),
              const SizedBox(height: 8),
              _DetailLine(label: 'Theme source', value: state.source.name),
              _DetailLine(
                label: 'Location',
                value: state.latitude == null
                    ? 'Not configured'
                    : '${state.latitude!.toStringAsFixed(2)}, ${state.longitude!.toStringAsFixed(2)}',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RecordingCacheControl extends ConsumerWidget {
  const _RecordingCacheControl();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(recordingSettingsProvider);
    final maxGb = switch (settings) {
      AsyncData(value: final value) => value.maxCacheGb,
      _ => 20,
    };
    final controller = ref.read(recordingSettingsProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Recording cache',
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Text(
              '$maxGb GB',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        Slider(
          value: maxGb.toDouble(),
          min: 1,
          max: 20,
          divisions: 19,
          label: '$maxGb GB',
          onChanged: (value) => controller.setMaxCacheGb(value.round()),
        ),
        Text(
          'Oldest closed segments are removed first.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

String _clockTypefaceFamily(ClockTypeface typeface) => switch (typeface) {
  ClockTypeface.sculpted => 'Unbounded',
  ClockTypeface.serif => 'Bodoni Moda',
  ClockTypeface.rounded => 'Quicksand',
  ClockTypeface.outline => 'Monoton',
  ClockTypeface.layered => 'Bungee Shade',
  ClockTypeface.inline => 'Fascinate Inline',
  ClockTypeface.stencil => 'Tourney',
  ClockTypeface.techno => 'Bruno Ace',
};

FontWeight _fontWeight(int value) => FontWeight.values[(value ~/ 100) - 1];

String _clockTypefaceLabel(ClockTypeface typeface) => switch (typeface) {
  ClockTypeface.sculpted => 'Sculpted',
  ClockTypeface.serif => 'Serif',
  ClockTypeface.rounded => 'Rounded',
  ClockTypeface.outline => 'Outline',
  ClockTypeface.layered => 'Layered',
  ClockTypeface.inline => 'Inline',
  ClockTypeface.stencil => 'Stencil',
  ClockTypeface.techno => 'Techno',
};

double _clockPreviewSize(ClockTypeface typeface) => switch (typeface) {
  ClockTypeface.layered => 38,
  ClockTypeface.outline || ClockTypeface.inline || ClockTypeface.techno => 42,
  _ => 48,
};

class _ClockTypefacePicker extends StatelessWidget {
  const _ClockTypefacePicker({
    required this.selected,
    required this.weight,
    required this.onSelected,
    this.compact = false,
    this.subject = 'clock',
  });

  final ClockTypeface selected;
  final int weight;
  final ValueChanged<ClockTypeface> onSelected;
  final bool compact;
  final String subject;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 8.0;
        final width = (constraints.maxWidth - spacing * 3) / 4;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: ClockTypeface.values.map((typeface) {
            final active = selected == typeface;
            final fontFamily = _clockTypefaceFamily(typeface);
            return Tooltip(
              message: _clockTypefaceLabel(typeface),
              child: Semantics(
                button: true,
                selected: active,
                label: '${_clockTypefaceLabel(typeface)} $subject typeface',
                child: Material(
                  color: active
                      ? Theme.of(context).colorScheme.secondaryContainer
                      : Theme.of(context).colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => onSelected(typeface),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      width: width,
                      height: compact ? 62 : 92,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: active
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.outlineVariant,
                          width: active ? 2 : 1,
                        ),
                      ),
                      child: Text(
                        '12',
                        maxLines: 1,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontFamily: fontFamily,
                          fontWeight: _fontWeight(weight),
                          fontSize: compact
                              ? _clockPreviewSize(typeface) * 0.68
                              : _clockPreviewSize(typeface),
                          height: 1,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _ColorSwatchButton extends StatelessWidget {
  const _ColorSwatchButton({
    required this.label,
    required this.color,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        selected: selected,
        button: true,
        child: InkResponse(
          onTap: onPressed,
          radius: 27,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              border: Border.all(
                color: selected
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(context).colorScheme.outlineVariant,
                width: selected ? 3 : 1,
              ),
            ),
            child: selected
                ? Icon(
                    Icons.check_rounded,
                    color:
                        ThemeData.estimateBrightnessForColor(color) ==
                            Brightness.dark
                        ? Colors.white
                        : Colors.black,
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showVivyPanel(
  BuildContext context, {
  required String title,
  required Widget child,
  bool landscapeWorkspace = false,
}) {
  final size = MediaQuery.sizeOf(context);
  final shortLandscape =
      landscapeWorkspace && size.width > size.height && size.height < 500;
  if (shortLandscape) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close $title',
      barrierColor: Colors.black.withValues(alpha: 0.36),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (context, _, _) => Material(
        child: _PanelFrame(title: title, child: child),
      ),
      transitionBuilder: (context, animation, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      ),
    );
  }
  final wide = size.width >= 900;
  if (!wide) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.78,
      ),
      builder: (context) => _PanelFrame(title: title, child: child),
    );
  }
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close $title',
    barrierColor: Colors.black.withValues(alpha: 0.36),
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (context, _, _) => Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        width: 440,
        height: double.infinity,
        child: Material(
          child: _PanelFrame(title: title, child: child),
        ),
      ),
    ),
    transitionBuilder: (context, animation, _, child) => SlideTransition(
      position: Tween(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
      child: FadeTransition(opacity: animation, child: child),
    ),
  );
}

class _PanelFrame extends StatelessWidget {
  const _PanelFrame({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final short = MediaQuery.sizeOf(context).height < 500;
    return SafeArea(
      child: Padding(
        padding: short
            ? const EdgeInsets.fromLTRB(20, 8, 20, 12)
            : const EdgeInsets.fromLTRB(28, 18, 28, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style:
                        (short
                                ? Theme.of(context).textTheme.titleLarge
                                : Theme.of(context).textTheme.headlineSmall)
                            ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            SizedBox(height: short ? 8 : 24),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}
