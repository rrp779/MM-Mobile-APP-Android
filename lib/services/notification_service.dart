import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/backend_config.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  String? _currentToken;
  String? get currentToken => _currentToken;

  /// Initialize FCM listeners and register token with backend
  Future<void> initialize() async {
    try {
      final messaging = FirebaseMessaging.instance;

      // 1. Request Notification Permissions (Handles iOS & Android 13+)
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      if (kDebugMode) {
        print("[NotificationService] Permission status: ${settings.authorizationStatus}");
      }

      // 2. Retrieve initial FCM Token
      _currentToken = await messaging.getToken();
      if (kDebugMode) {
        print("[NotificationService] FCM Token: $_currentToken");
      }

      if (_currentToken != null) {
        await syncTokenWithBackend(token: _currentToken);
      }

      // 3. Listen to Token Refresh events
      messaging.onTokenRefresh.listen((newToken) async {
        _currentToken = newToken;
        if (kDebugMode) {
          print("[NotificationService] FCM Token refreshed: $newToken");
        }
        await syncTokenWithBackend(token: newToken);
      });
    } catch (e) {
      if (kDebugMode) {
        print("[NotificationService] Initialization error: $e");
      }
    }
  }

  /// Sync device token and customer identifiers with backend
  Future<void> syncTokenWithBackend({
    String? token,
    String? customerId,
    String? email,
    String? phone,
  }) async {
    final activeToken = token ?? _currentToken;
    if (activeToken == null || activeToken.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();

      // Persist latest known identifiers
      if (customerId != null && customerId.isNotEmpty) {
        await prefs.setString('fcm_last_customer_id', customerId);
      }
      if (email != null && email.isNotEmpty) {
        await prefs.setString('fcm_last_email', email);
      }
      if (phone != null && phone.isNotEmpty) {
        await prefs.setString('fcm_last_phone', phone);
      }

      // Read from arguments or fallback to persistent cache
      String? finalCustomerId = customerId ?? prefs.getString('fcm_last_customer_id');
      String? finalEmail = email ?? prefs.getString('fcm_last_email');
      String? finalPhone = phone ?? prefs.getString('fcm_last_phone');

      if (finalCustomerId == null && finalEmail == null && finalPhone == null) {
        final customerRaw = prefs.getString('customer');
        if (customerRaw != null) {
          try {
            final customer = jsonDecode(customerRaw);
            finalCustomerId = customer['id']?.toString();
            finalEmail = customer['email']?.toString();
            finalPhone = customer['phone']?.toString();
          } catch (_) {}
        }
      }

      final url = Uri.parse("${BackendConfig.baseUrl}/notifications/register-token");
      final body = {
        "fcmToken": activeToken,
        "customerId": finalCustomerId,
        "email": finalEmail,
        "phone": finalPhone,
        "platform": Platform.isIOS ? "ios" : "android",
        "appVersion": "1.0.15",
      };

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      if (kDebugMode) {
        print("[NotificationService] Token sync response (${response.statusCode}): ${response.body}");
      }
    } catch (e) {
      if (kDebugMode) {
        print("[NotificationService] Error syncing token with backend: $e");
      }
    }
  }

  /// Deactivate token on logout
  Future<void> unregisterOnLogout() async {
    if (_currentToken == null) return;

    try {
      final url = Uri.parse("${BackendConfig.baseUrl}/notifications/unregister-token");
      await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"fcmToken": _currentToken}),
      );
      if (kDebugMode) {
        print("[NotificationService] Token successfully deactivated on backend");
      }
    } catch (e) {
      if (kDebugMode) {
        print("[NotificationService] Error unregistering token: $e");
      }
    }
  }
}
