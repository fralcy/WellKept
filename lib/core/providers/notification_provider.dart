import 'package:flutter/widgets.dart';

import '../l10n/app_localizations.dart';
import '../models/scheduled_reminder.dart';
import '../utils/notification_service.dart';
import '../utils/notification_service_base.dart';
import '../utils/reminder_planner_service.dart';
import 'settings_provider.dart';
import 'tracked_item_provider.dart';

/// Bridge between the data ([TrackedItemProvider]) / reminder time and
/// language ([SettingsProvider]) and the OS notification queue: on any
/// change, re-plans every reminder and replaces the whole queue.
class NotificationProvider extends ChangeNotifier {
  NotificationProvider({
    required TrackedItemProvider itemProvider,
    required SettingsProvider settingsProvider,
    NotificationServiceBase? notificationService,
    ReminderPlannerService planner = const ReminderPlannerService(),
    DateTime Function()? clock,
  }) : _items = itemProvider,
       _settings = settingsProvider,
       _service = notificationService ?? NotificationService.instance,
       _planner = planner,
       _clock = clock ?? DateTime.now {
    _items.addListener(_onChanged);
    _settings.addListener(_onChanged);
  }

  final TrackedItemProvider _items;
  final SettingsProvider _settings;
  final NotificationServiceBase _service;
  final ReminderPlannerService _planner;
  final DateTime Function() _clock;

  bool _initialized = false;
  bool _permissionRequested = false;

  /// Serializes scheduling passes, so a burst of changes can't interleave
  /// two `replaceAll` calls on the OS queue.
  Future<void> _queue = Future.value();

  List<ScheduledReminder> _scheduled = const [];

  /// What the last pass handed to the OS — mainly for tests/debugging.
  List<ScheduledReminder> get scheduled => List.unmodifiable(_scheduled);

  Future<void> init() async {
    try {
      await _service.init();
      _initialized = true;
    } catch (e, st) {
      // Notifications failing must not stop the app — everything else
      // works without them.
      debugPrint('NotificationService init failed: $e\n$st');
      return;
    }
    await rescheduleAll();
  }

  void _onChanged() {
    if (_initialized) rescheduleAll();
  }

  Future<void> rescheduleAll() {
    return _queue = _queue.then((_) => _reschedule());
  }

  Future<void> _reschedule() async {
    try {
      final now = _clock();
      final l10n = lookupAppLocalizations(Locale(_settings.languageCode));
      final reminders = _planner.plan(
        items: _items.items,
        statusFor: (item) => _items.statusFor(item, today: now),
        hour: _settings.reminderHour,
        minute: _settings.reminderMinute,
        l10n: l10n,
        now: now,
      );

      // Ask only once there's actually something to remind about, rather
      // than on first launch before the user has added anything.
      if (reminders.isNotEmpty && !_permissionRequested) {
        _permissionRequested = true;
        await _service.requestPermission();
      }

      await _service.replaceAll(
        reminders,
        channelName: l10n.notificationChannelName,
        channelDescription: l10n.notificationChannelDescription,
      );
      _scheduled = reminders;
      notifyListeners();
    } catch (e, st) {
      debugPrint('Rescheduling reminders failed: $e\n$st');
    }
  }

  @override
  void dispose() {
    _items.removeListener(_onChanged);
    _settings.removeListener(_onChanged);
    super.dispose();
  }
}
