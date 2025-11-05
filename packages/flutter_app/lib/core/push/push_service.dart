
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../api_client.dart';

class PushService {
  PushService._();

  static const _enabled = bool.fromEnvironment('PUSH_NOTIFICATIONS_ENABLED', defaultValue: false);

  static const _fbApiKey = String.fromEnvironment('FIREBASE_API_KEY', defaultValue: '');
  static const _fbAppId = String.fromEnvironment('FIREBASE_APP_ID', defaultValue: '');
  static const _fbSenderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID', defaultValue: '');
  static const _fbProjectId = String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: '');
  static const _fbVapidKey = String.fromEnvironment('FIREBASE_VAPID_KEY', defaultValue: '');
  static const _fbAuthDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN', defaultValue: '');
  static const _fbStorageBucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET', defaultValue: '');

  static bool get isEnabled => _enabled;

  static Future<bool> initializeAndRegister(BuildContext context) async {
    if (!_enabled) return false;

    if (!kIsWeb) {
      // This demo is web-focused; early return on non-web targets.
      return false;
    }

    if (_fbApiKey.isEmpty || _fbAppId.isEmpty || _fbSenderId.isEmpty || _fbProjectId.isEmpty || _fbVapidKey.isEmpty) {
      debugPrint('[Push] Missing firebase dart-defines; skipping push init.');
      _showSnack(context, 'Push not configured (missing Firebase defines)');
      return false;
    }

    try {
      // Initialize Firebase (no-op if already initialized)
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: FirebaseOptions(
            apiKey: _fbApiKey,
            appId: _fbAppId,
            messagingSenderId: _fbSenderId,
            projectId: _fbProjectId,
            authDomain: _fbAuthDomain.isEmpty ? null : _fbAuthDomain,
            storageBucket: _fbStorageBucket.isEmpty ? null : _fbStorageBucket,
          ),
        );
      }

      final messaging = FirebaseMessaging.instance;

      // Request permission
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        _showSnack(context, 'Push permission denied');
        return false;
      }

      // Get token (requires VAPID key on web)
      final token = await messaging.getToken(vapidKey: _fbVapidKey);
      if (token == null || token.isEmpty) {
        _showSnack(context, 'Failed to get push token');
        return false;
      }

      debugPrint('[Push] FCM token: $token');

      // Send token to backend
      await ApiClient.I.registerPushToken(
        token: token,
        platform: 'web',
        userAgent: _userAgent(),
      );

      // Foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final title = message.notification?.title ?? message.data['title'] ?? 'Message';
        final body = message.notification?.body ?? message.data['body'] ?? '[no body]';
        _showSnack(context, 'Push: $title — $body');
      });

      _showSnack(context, 'Push enabled');
      return true;
    } catch (e, st) {
      debugPrint('[Push] init failed: $e\n$st');
      _showSnack(context, 'Push init failed');
      return false;
    }
  }

  static void _showSnack(BuildContext context, String msg) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  static String? _userAgent() {
    // Only web exposes a user agent via dart:html; keep this simple to avoid importing html here.
    // You could pass UA from the UI call-site if needed.
    return null;
  }
}
