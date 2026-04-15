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
}