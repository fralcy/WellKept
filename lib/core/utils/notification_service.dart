// Cross-platform reminder scheduling. `NotificationService` is defined
// three times with the exact same public API (see `_stub`/`_io`/`_web`);
// only one file's declarations are ever compiled in for a given target,
// picked by this conditional export.
export 'notification_service_stub.dart'
    if (dart.library.io) 'notification_service_io.dart'
    if (dart.library.js_interop) 'notification_service_web.dart';
