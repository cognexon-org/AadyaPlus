import 'dart:async';
import 'dart:convert';

import 'package:aadya_plus/services/api_client.dart' as http;
import 'package:aadya_plus/services/notification_navigation_service.dart';
import 'package:aadya_plus/services/secure_storage_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

const AndroidNotificationChannel _aadyaChannel = AndroidNotificationChannel(
  'aadya_high_importance',
  'Aadya Plus alerts',
  description: 'Appointments, prescriptions, diagnostics, orders and messages',
  importance: Importance.high,
);

FirebaseOptions? _firebaseOptionsFromEnvironment() {
  const genericApiKey = String.fromEnvironment('AADYA_FIREBASE_API_KEY');
  const genericAppId = String.fromEnvironment('AADYA_FIREBASE_APP_ID');
  const androidApiKey =
      String.fromEnvironment('AADYA_FIREBASE_ANDROID_API_KEY');
  const androidAppId =
      String.fromEnvironment('AADYA_FIREBASE_ANDROID_APP_ID');
  const iosApiKey = String.fromEnvironment('AADYA_FIREBASE_IOS_API_KEY');
  const iosAppId = String.fromEnvironment('AADYA_FIREBASE_IOS_APP_ID');
  const senderId =
      String.fromEnvironment('AADYA_FIREBASE_MESSAGING_SENDER_ID');
  const projectId = String.fromEnvironment('AADYA_FIREBASE_PROJECT_ID');
  const storageBucket = String.fromEnvironment('AADYA_FIREBASE_STORAGE_BUCKET');
  const iosBundleId = String.fromEnvironment('AADYA_FIREBASE_IOS_BUNDLE_ID');

  var apiKey = genericApiKey;
  var appId = genericAppId;
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    if (androidApiKey.trim().isNotEmpty) apiKey = androidApiKey;
    if (androidAppId.trim().isNotEmpty) appId = androidAppId;
  } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
    if (iosApiKey.trim().isNotEmpty) apiKey = iosApiKey;
    if (iosAppId.trim().isNotEmpty) appId = iosAppId;
  }

  if ([apiKey, appId, senderId, projectId].any((value) => value.trim().isEmpty)) {
    return null;
  }

  return FirebaseOptions(
    apiKey: apiKey.trim(),
    appId: appId.trim(),
    messagingSenderId: senderId.trim(),
    projectId: projectId.trim(),
    storageBucket: storageBucket.trim().isEmpty ? null : storageBucket.trim(),
    iosBundleId: iosBundleId.trim().isEmpty ? null : iosBundleId.trim(),
  );
}

Future<void> _ensureFirebaseInitialized() async {
  if (Firebase.apps.isNotEmpty) return;
  final options = _firebaseOptionsFromEnvironment();
  if (options != null) {
    await Firebase.initializeApp(options: options);
  } else {
    // Supports projects that prefer native Firebase configuration files.
    await Firebase.initializeApp();
  }
}

@pragma('vm:entry-point')
Future<void> aadyaFirebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await _ensureFirebaseInitialized();
  } catch (error) {
    debugPrint('Aadya push background initialization failed: $error');
  }
}

/// Patient-app push lifecycle and backend device-token registration.
///
/// Push failure never prevents the core healthcare app from starting. This is
/// important for developer builds that have not yet been given Firebase
/// configuration and for devices where notification permission is denied.
class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final StreamController<int> _notificationEvents =
      StreamController<int>.broadcast();

  Stream<int> get notificationEvents => _notificationEvents.stream;

  bool _initialized = false;
  bool _available = false;
  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  String? _currentToken;
  String? _lastOpenFingerprint;
  DateTime? _lastOpenedAt;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      await _ensureFirebaseInitialized();
      _available = true;

      const initializationSettings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      );

      await _localNotifications.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: (response) {
          final payload = response.payload;
          if (payload == null || payload.isEmpty) return;
          try {
            final decoded = json.decode(payload);
            if (decoded is Map) {
              openNotificationData(Map<String, dynamic>.from(decoded));
            }
          } catch (error) {
            debugPrint('Invalid local notification payload: $error');
          }
        },
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_aadyaChannel);

      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      await messaging.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: true,
        sound: false,
      );

      _foregroundSubscription = FirebaseMessaging.onMessage.listen(
        _handleForegroundMessage,
      );
      _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
        (message) => openNotificationData(_dataFromMessage(message)),
      );
      _tokenRefreshSubscription = messaging.onTokenRefresh.listen(
        (token) async {
          _currentToken = token;
          await _registerToken(token);
        },
      );

      final localLaunch =
          await _localNotifications.getNotificationAppLaunchDetails();
      final localPayload = localLaunch?.notificationResponse?.payload;
      if (localLaunch?.didNotificationLaunchApp == true &&
          localPayload != null &&
          localPayload.isNotEmpty) {
        try {
          final decoded = json.decode(localPayload);
          if (decoded is Map) {
            await openNotificationData(Map<String, dynamic>.from(decoded));
          }
        } catch (error) {
          debugPrint('Invalid launch notification payload: $error');
        }
      }

      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        await openNotificationData(_dataFromMessage(initialMessage));
      }

      await syncAuthenticatedDevice();
    } catch (error) {
      _available = false;
      debugPrint(
        'Push notifications are unavailable in this build: $error. '
        'Configure Firebase before release.',
      );
    }
  }

  Future<void> syncAuthenticatedDevice() async {
    if (!_initialized) await initialize();
    if (!_available) return;

    final authToken = await SecureStorageService.instance.readToken();
    if (authToken == null || authToken.isEmpty) return;

    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      _currentToken = token;
      await _registerToken(token);
    } catch (error) {
      debugPrint('Unable to synchronize push token: $error');
    }
  }

  Future<void> unregisterAuthenticatedDevice() async {
    if (!_available) return;
    final token = _currentToken ?? await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) return;

    try {
      await http.delete(
        http.apiUri('/notifications/device-token'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'token': token, 'app': 'aadyaplus'}),
      );
    } catch (error) {
      // Logout must not be blocked by a push cleanup failure.
      debugPrint('Unable to unregister push token: $error');
    }
  }

  Future<void> openNotificationData(Map<String, dynamic> data) async {
    final normalized = data.map(
      (key, value) => MapEntry(key.toString(), value),
    );
    final fingerprint = [
      normalized['notificationId'],
      normalized['type'],
      normalized['relatedEntityId'],
      normalized['orderId'],
    ].map((value) => value?.toString() ?? '').join('|');

    final now = DateTime.now();
    if (_lastOpenFingerprint == fingerprint &&
        _lastOpenedAt != null &&
        now.difference(_lastOpenedAt!).inSeconds < 3) {
      return;
    }
    _lastOpenFingerprint = fingerprint;
    _lastOpenedAt = now;

    final notificationId = normalized['notificationId']?.toString() ?? '';
    if (notificationId.isNotEmpty) {
      try {
        await http.put(http.apiUri('/notifications/$notificationId/read'));
      } catch (error) {
        debugPrint('Unable to mark opened notification as read: $error');
      }
    }

    _notificationEvents.add(DateTime.now().millisecondsSinceEpoch);
    await NotificationNavigationService.instance.open(normalized);
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final data = _dataFromMessage(message);
    _notificationEvents.add(DateTime.now().millisecondsSinceEpoch);

    final title = message.notification?.title ?? data['title']?.toString();
    final body = message.notification?.body ?? data['message']?.toString();
    if ((title ?? '').isEmpty && (body ?? '').isEmpty) return;

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _aadyaChannel.id,
        _aadyaChannel.name,
        channelDescription: _aadyaChannel.description,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    final localId = (message.messageId?.hashCode ??
            DateTime.now().millisecondsSinceEpoch.hashCode) &
        0x7fffffff;
    await _localNotifications.show(
      id: localId,
      title: title ?? 'Aadya Plus',
      body: body ?? '',
      notificationDetails: details,
      payload: json.encode(data),
    );
  }

  Future<void> _registerToken(String token) async {
    final authToken = await SecureStorageService.instance.readToken();
    if (authToken == null || authToken.isEmpty) return;

    try {
      final response = await http.post(
        http.apiUri('/notifications/device-token'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'token': token,
          'platform': _platformName(),
          'app': 'aadyaplus',
        }),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint(
          'Push token registration failed (${response.statusCode}): '
          '${response.body}',
        );
      }
    } catch (error) {
      debugPrint('Push token registration failed: $error');
    }
  }

  Map<String, dynamic> _dataFromMessage(RemoteMessage message) {
    final data = Map<String, dynamic>.from(message.data);
    if (message.notification?.title != null) {
      data.putIfAbsent('title', () => message.notification!.title!);
    }
    if (message.notification?.body != null) {
      data.putIfAbsent('message', () => message.notification!.body!);
    }
    return data;
  }

  String _platformName() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      default:
        return 'unknown';
    }
  }

  Future<void> dispose() async {
    await _tokenRefreshSubscription?.cancel();
    await _foregroundSubscription?.cancel();
    await _openedSubscription?.cancel();
    await _notificationEvents.close();
  }
}
