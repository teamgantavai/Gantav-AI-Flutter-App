export 'notification_service_mobile.dart'
    if (dart.library.html) 'notification_service_web.dart'
    if (dart.library.js_interop) 'notification_service_web.dart';
