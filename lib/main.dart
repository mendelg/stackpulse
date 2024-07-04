import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

// Conditional import for notification service
import 'notification_service.dart'
    if (dart.library.html) 'web_notification_service.dart';
import 'notification_service_interface.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initNotifications();
  runApp(MyApp());
}

Future<void> initNotifications() async {
  if (!kIsWeb) {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('app_icon');
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
    await flutterLocalNotificationsPlugin.initialize(
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
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'StackPulse',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: StackOverflowNotifier(),
    );
  }
}

class StackOverflowNotifier extends StatefulWidget {
  @override
  _StackOverflowNotifierState createState() => _StackOverflowNotifierState();
}

class _StackOverflowNotifierState extends State<StackOverflowNotifier> {
  WebSocketChannel? _channel;
  List<String> _tags = [];
  List<Map<String, dynamic>> _notifications = [];
  TextEditingController _tagController = TextEditingController();
  SharedPreferences? _prefs;
  bool _notificationsEnabled = false;
  late NotificationServiceInterface _notificationService;
  final Set<String> _recentNotifications = {};
  final Set<String> _fetchedQuestionIds = {};
  final Duration _debounceDuration = Duration(seconds: 10);

  @override
  void initState() {
    super.initState();
    _notificationService = NotificationService();
    _initSharedPreferences();
    _connectWebSocket();
    _checkNotificationPermissions();
    _requestNotificationPermissions();
  }

  Future<void> _initSharedPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    _loadSavedData();
  }

  void _loadSavedData() {
    setState(() {
      _tags = _prefs!.getStringList('tags') ?? [];
      String? notificationsJson = _prefs!.getString('notifications');
      if (notificationsJson != null) {
        _notifications = (json.decode(notificationsJson) as List)
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
    });
    _tags.forEach(_subscribeToTag);
  }

  void _saveData() {
    _prefs!.setStringList('tags', _tags);
    _prefs!.setString('notifications', json.encode(_notifications));
  }

  void _connectWebSocket() {
    _channel = WebSocketChannel.connect(
      Uri.parse('wss://qa.sockets.stackexchange.com/'),
    );
    _channel!.stream.listen(_handleMessage,
        onDone: _reconnect, onError: (_) => _reconnect());
  }

  void _reconnect() {
    Future.delayed(Duration(seconds: 5), () {
      if (mounted) {
        _connectWebSocket();
        _tags.forEach(_subscribeToTag);
      }
    });
  }

  void _handleMessage(message) {
    final data = json.decode(message);
    if (data['action'] == 'hb') {
      _channel!.sink.add('pong');
    } else if (data['data'] != null) {
      final questionData = json.decode(data['data']);
      if (!_fetchedQuestionIds.contains(questionData['id'])) {
        _fetchedQuestionIds.add(questionData['id']);
        _fetchQuestionDetails(questionData['id']);
      }
    }
  }

  void _fetchQuestionDetails(String questionId) async {
    final response = await http.get(Uri.parse(
        'https://api.stackexchange.com/2.3/questions/$questionId?site=stackoverflow&filter=withbody'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['items'] != null && data['items'].isNotEmpty) {
        final question = data['items'][0];
        setState(() {
          _notifications.insert(0, question);
          if (_notifications.length > 10) _notifications.removeLast();
          _saveData();
        });
        if (_notificationsEnabled &&
            !_recentNotifications.contains(question['link'])) {
          _showNotification(question['title'], question['link']);
          _recentNotifications.add(question['link']);
          Future.delayed(_debounceDuration, () {
            _recentNotifications.remove(question['link']);
          });
        }
      }
    }
  }

  Future<void> _checkNotificationPermissions() async {
    _notificationsEnabled = await _notificationService.checkPermissions();
    setState(() {});
  }

  Future<void> _requestNotificationPermissions() async {
    _notificationsEnabled = await _notificationService.requestPermissions();
    setState(() {});
  }

  void _showNotification(String title, String url) async {
    _notificationService.showNotification(
        'New Stack Overflow Question', title, url);
  }

  void _addTag() {
    final newTag = _tagController.text.trim();
    if (newTag.isNotEmpty && !_tags.contains(newTag)) {
      setState(() {
        _tags.add(newTag);
        _saveData();
      });
      _subscribeToTag(newTag);
      _tagController.clear();
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
      _saveData();
    });
  }

  void _subscribeToTag(String tag) {
    _channel!.sink.add('1-questions-newest-tag-$tag');
  }

  void _removeNotification(int index) {
    setState(() {
      _notifications.removeAt(index);
      _saveData();
    });
  }

  void _clearNotifications() {
    setState(() {
      _notifications.clear();
      _saveData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: SvgPicture.asset(
          'assets/logo.svg',
          // fit: BoxFit.fill,
        ),
        centerTitle: true,
        actions: [
          ElevatedButton(
            onPressed:
                _notificationsEnabled ? null : _requestNotificationPermissions,
            child: Text(_notificationsEnabled
                ? 'Notifications Enabled'
                : 'Enable Notifications'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(30.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _tagController,
                    decoration: InputDecoration(
                      hintText: 'Enter a tag',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addTag,
                  child: Text('Add Tag'),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 8,
            children: _tags
                .map((tag) => Chip(
                      label: Text(tag),
                      onDeleted: () => _removeTag(tag),
                    ))
                .toList(),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              icon: Icon(Icons.delete_sweep),
              onPressed: _clearNotifications,
              tooltip: 'Clear All Notifications',
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _notifications.length,
              itemBuilder: (context, index) {
                final notification = _notifications[index];
                return Dismissible(
                  key: Key(notification['link']),
                  onDismissed: (direction) {
                    _removeNotification(index);
                  },
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: EdgeInsets.symmetric(horizontal: 10.0),
                    child: Icon(Icons.delete, color: Colors.white),
                  ),
                  child: Card(
                    margin: EdgeInsets.all(8),
                    child: ListTile(
                      title: Text(notification['title']),
                      subtitle: Text(notification['tags'].join(', ')),
                      onTap: () {
                        launchUrl(Uri.parse(notification['link']));
                      },
                      trailing: IconButton(
                        icon: Icon(Icons.delete),
                        onPressed: () => _removeNotification(index),
                        tooltip: 'Remove Notification',
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _channel?.sink.close();
    _tagController.dispose();
    super.dispose();
  }
}
