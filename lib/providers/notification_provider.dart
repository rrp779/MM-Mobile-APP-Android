import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/notification_model.dart';

class NotificationProvider extends ChangeNotifier {
  final Box<AppNotification> box =
  Hive.box<AppNotification>('notifications');

  List<AppNotification> get notifications =>
      box.values.toList().reversed.toList();

  void addNotification(AppNotification notification) {
    box.add(notification);
    notifyListeners();
  }

  void clearAll() {
    box.clear();
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