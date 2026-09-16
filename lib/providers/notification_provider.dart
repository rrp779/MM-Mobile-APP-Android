import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/notification_model.dart';

class NotificationProvider extends ChangeNotifier {
  final Box<AppNotification> box =
  Hive.box<AppNotification>('notifications');

  DateTime? _lastReadAt;

  NotificationProvider() {
    _loadLastReadAt();
  }

  Future<void> _loadLastReadAt() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ms = prefs.getInt('last_read_notifications_at');
      if (ms != null && ms > 0) {
        _lastReadAt = DateTime.fromMillisecondsSinceEpoch(ms);
        notifyListeners();
      }
    } catch (_) {}
  }

  List<AppNotification> get notifications =>
      box.values.toList().reversed.toList();

  int get unreadCount {
    if (_lastReadAt == null) {
      return box.length;
    }
    return box.values.where((n) => n.time.isAfter(_lastReadAt!)).length;
  }

  Future<void> markAllAsRead() async {
    _lastReadAt = DateTime.now();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('last_read_notifications_at', _lastReadAt!.millisecondsSinceEpoch);
    } catch (_) {}
  }

  void addNotification(AppNotification notification) {
    // Avoid duplicate within 10 seconds
    final isDuplicate = box.values.any((n) =>
        n.title.trim() == notification.title.trim() &&
        n.body.trim() == notification.body.trim() &&
        notification.time.difference(n.time).inSeconds.abs() < 10);
    if (!isDuplicate) {
      box.add(notification);
      notifyListeners();
    }
  }

  void clearAll() {
    box.clear();
    _lastReadAt = DateTime.now();
    notifyListeners();
  }

  void removeNotificationWhere(bool Function(AppNotification) test) {
    final keysToDelete = <dynamic>[];
    for (final key in box.keys) {
      final value = box.get(key);
      if (value != null && test(value)) {
        keysToDelete.add(key);
      }
    }
    for (final key in keysToDelete) {
      box.delete(key);
    }
    notifyListeners();
  }
}