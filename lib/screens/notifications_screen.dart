import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/notification_provider.dart';
import '../models/notification_model.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<NotificationProvider>(context);
    final notifications = provider.notifications;
    void handleNotificationClick(BuildContext context, AppNotification n) {
      if (n.type == 'product' && n.handle != null) {
        Navigator.pushNamed(
          context,
          '/product',
          arguments: n.handle,
        );

      } else if (n.type == 'collection' && n.handle != null) {
        Navigator.pushNamed(
          context,
          '/collection',
          arguments: {
            "collectionId": n.handle,
            "handle": n.handle,
            "title": n.titleArg ?? "Collection",
          },
        );

      } else if (n.type == 'cart') {
        Navigator.pushNamed(context, '/cart');

      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No action available")),
        );
      }
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text("Notifications"),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              provider.clearAll();
            },
          )
        ],
      ),
      body: notifications.isEmpty
          ? const Center(child: Text("No notifications yet"))
          : ListView.builder(
        itemCount: notifications.length,
        itemBuilder: (context, index) {
          final n = notifications[index];

          return Card(
            margin: const EdgeInsets.all(8),
            child: ListTile(
              onTap: () {
                handleNotificationClick(context, n);
              },
              leading: const Icon(Icons.notifications),
              title: Text(n.title),
              subtitle: Text(n.body),
              trailing: Text(
                "${n.time.hour}:${n.time.minute}",
              ),
            ),
          );
        },
      ),
    );
  }
}