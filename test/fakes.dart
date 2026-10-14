import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:well_kept/core/models/scheduled_reminder.dart';
import 'package:well_kept/core/utils/notification_service_base.dart';
import 'package:well_kept/core/utils/photo_picker_service.dart';

/// Records calls instead of touching the platform notification plugin.
class FakeNotificationService implements NotificationServiceBase {
  FakeNotificationService({this.permissionGranted = true, this.launchedFrom});

  final bool permissionGranted;

  /// Simulates the app being launched by tapping this item's reminder.
  final String? launchedFrom;

  final _taps = StreamController<String>.broadcast();

  /// Simulates the user tapping a reminder for [itemId] while running.
  void tap(String itemId) => _taps.add(itemId);

  @override
  Stream<String> get tappedItemIds => _taps.stream;

  @override
  Future<String?> launchItemId() async => launchedFrom;

  int initCalls = 0;
  int permissionRequests = 0;
  List<ScheduledReminder> scheduled = const [];
  String? lastChannelName;
  int replaceCalls = 0;

  @override
  Future<void> init() async => initCalls++;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return permissionGranted;
  }

  @override
  Future<void> replaceAll(
    List<ScheduledReminder> reminders, {
    required String channelName,
    required String channelDescription,
  }) async {
    replaceCalls++;
    scheduled = List.of(reminders);
    lastChannelName = channelName;
  }
}

/// Returns a valid 1×1 PNG instead of opening the platform picker, or null
/// (the user cancelling) when [cancels] is set.
class FakePhotoPicker extends PhotoPickerService {
  FakePhotoPicker({bool cancels = false})
    : bytes = cancels ? null : onePixelPng;

  final Uint8List? bytes;
  final List<PhotoSource> requests = [];

  @override
  Future<Uint8List?> pick(PhotoSource source) async {
    requests.add(source);
    return bytes;
  }
}

/// A valid 1×1 PNG, so Image.memory can actually decode it.
final Uint8List onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg==',
);
