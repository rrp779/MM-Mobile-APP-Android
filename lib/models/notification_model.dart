import 'package:hive/hive.dart';

part 'notification_model.g.dart';

@HiveType(typeId: 0)
class AppNotification extends HiveObject {
  @HiveField(0)
  final String title;

  @HiveField(1)
  final String body;

  @HiveField(2)
  final DateTime time;

  @HiveField(3)
  final String? type;

  @HiveField(4)
  final String? handle;

  @HiveField(5)
  final String? titleArg;

  AppNotification({
    required this.title,
    required this.body,
    required this.time,
    this.type,
    this.handle,
    this.titleArg,
  });
}