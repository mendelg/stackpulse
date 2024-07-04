import 'package:url_launcher/url_launcher.dart';
import 'package:windows_notification/notification_message.dart';
import 'package:windows_notification/windows_notification.dart';
import 'notification_service_interface.dart';

class WindowsNotificationService implements NotificationServiceInterface {
  final _winNotifyPlugin = WindowsNotification(applicationId: getApplicationId());


  static String? getApplicationId() {
    // Return the application ID in debug mode, otherwise null, since it'll crash without ID in debug mode
    if (bool.fromEnvironment('dart.vm.product')) {
      return null;
    } else {
      return "{D65231B0-B2F1-4857-A4CE-A8E7C6EA7D27}\\WindowsPowerShell\\v1.0\\powershell.exe"; // Debug mode
    }
  }

  @override
  Future<void> initNotification() async {
    // No specific initialization needed for Windows notifications
  }

  @override
  Future<bool> checkPermissions() async {
    // Windows notifications do not require explicit permissions
    return true;
  }

  @override
  Future<bool> requestPermissions() async {
    // Windows notifications do not require explicit permissions
    return true;
  }

  @override
  Future<void> showNotification(String title, String body, String url) async {
    NotificationMessage message = NotificationMessage.fromPluginTemplate(
      "notification_id",
      title,
      body,
      launch: url,
    );


    _winNotifyPlugin.showNotificationPluginTemplate(message);


  }
}
