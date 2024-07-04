import 'dart:js' as js;

import 'notification_service_interface.dart';

class NotificationService implements NotificationServiceInterface {
  @override
  Future<void> initNotification() async {
    // No initialization needed for web notifications
  }

  @override
  Future<bool> checkPermissions() async {
    return js.context['Notification']['permission'] == 'granted';
  }

  @override
  Future<bool> requestPermissions() async {
    js.context['Notification'].callMethod('requestPermission');
    await Future.delayed(Duration(seconds: 1));
    return js.context['Notification']['permission'] == 'granted';
  }

  @override
  Future<void> showNotification(String title, String body, String url) async {
    if (js.context['Notification'] != null &&
        js.context['Notification']['permission'] == 'granted') {
      var notification = js.JsObject(js.context['Notification'], [
        title,
        js.JsObject.jsify({'body': body})
      ]);

      notification.callMethod('addEventListener', [
        'click',
        js.allowInterop((_) {
          js.context.callMethod('open', [url, '_blank']);
        })
      ]);
    }
  }
}
