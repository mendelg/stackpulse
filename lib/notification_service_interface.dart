abstract class NotificationServiceInterface {
  Future<void> initNotification();

  Future<bool> checkPermissions();
  Future<bool> requestPermissions();
  Future<void> showNotification(String title, String body, String url);
}
