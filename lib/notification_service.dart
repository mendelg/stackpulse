import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:url_launcher/url_launcher.dart';

import 'notification_service_interface.dart';

class NotificationService implements NotificationServiceInterface {
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initNotification() async {
    if (kIsWeb) return;

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
      macOS: initializationSettingsDarwin,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse:
          (NotificationResponse notificationResponse) {
        final String? payload = notificationResponse.payload;
        if (payload != null) {
          launchUrl(Uri.parse(payload));
        }
      },
    );
  }

  @override
  Future<bool> requestPermissions() async {
    if (kIsWeb) return true;
    if (Platform.isIOS) {
      return await _flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin>()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    } else if (Platform.isMacOS) {
      return await _flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                  MacOSFlutterLocalNotificationsPlugin>()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    } else if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>();
      return await androidImplementation?.requestNotificationsPermission() ??
          false;
    }
    return true;
  }

  @override
  Future<bool> checkPermissions() async {
    if (kIsWeb) return true;
    if (Platform.isIOS || Platform.isMacOS) {
      final bool? result = await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      return result ?? false;
    } else if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>();
      return await androidImplementation?.areNotificationsEnabled() ?? false;
    }
    return true;
  }

  @override
  Future<void> showNotification(
      String title, String body, String payload) async {
    if (kIsWeb) return;

    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      'stack_overflow_channel',
      'Stack Overflow Notifications',
      channelDescription: 'Notifications for new Stack Overflow questions',
      importance: Importance.max,
      priority: Priority.high,
    );

    const DarwinNotificationDetails darwinNotificationDetails =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
      iOS: darwinNotificationDetails,
      macOS: darwinNotificationDetails,
    );

    await _flutterLocalNotificationsPlugin.show(
      0,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }
}
