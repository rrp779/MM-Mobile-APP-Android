import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../config/backend_config.dart';
import '../customer/customer_model.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_provider.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _remoteNotifications = [];
  Set<String> _dismissedKeys = {};

  @override
  void initState() {
    super.initState();
    _loadDismissedKeysAndFetch();
  }

  Future<void> _loadDismissedKeysAndFetch() async {
    final prefs = await SharedPreferences.getInstance();
    final savedKeys = prefs.getStringList('dismissed_notification_keys') ?? [];
    setState(() {
      _dismissedKeys = savedKeys.toSet();
    });
    await _fetchRemoteNotifications();
  }

  String _buildNotificationKey(String? title, String? body) {
    final t = (title ?? "").trim().toLowerCase();
    final b = (body ?? "").trim().toLowerCase();
    return "${t}__${b}";
  }

  Future<void> _fetchRemoteNotifications() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final customerModel = Provider.of<CustomerModel>(context, listen: false);

      final customer = customerModel.customer ?? auth.customer;

      String? phone = customer?['phone']?.toString() ?? prefs.getString('fcm_last_phone');
      String? email = customer?['email']?.toString() ?? prefs.getString('fcm_last_email');
      String? customerId = customer?['id']?.toString() ?? prefs.getString('fcm_last_customer_id');

      final queryParams = <String, String>{};
      if (phone != null && phone.trim().isNotEmpty) {
        queryParams['phone'] = phone.trim();
      }
      if (email != null && email.trim().isNotEmpty) {
        queryParams['email'] = email.trim();
      }
      if (customerId != null && customerId.trim().isNotEmpty) {
        queryParams['customerId'] = customerId.trim();
      }

      if (queryParams.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      final uri = Uri.parse("${BackendConfig.baseUrl}/notifications/history")
          .replace(queryParameters: queryParams);

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['notifications'] is List) {
          final lastClearedEpoch = prefs.getInt('last_cleared_notifications_at') ?? 0;
          final list = <Map<String, dynamic>>[];

          for (final n in data['notifications']) {
            if (n is Map<String, dynamic>) {
              final id = n['_id']?.toString() ?? "";
              final key = _buildNotificationKey(n['title'], n['body']);
              final legacyKey = "${n['title']}_${n['orderId'] ?? ''}_${n['status'] ?? ''}";

              if (_dismissedKeys.contains(id) || _dismissedKeys.contains(key) || _dismissedKeys.contains(legacyKey)) {
                continue;
              }

              if (lastClearedEpoch > 0 && n['sentAt'] != null) {
                try {
                  final dt = DateTime.parse(n['sentAt'].toString());
                  if (dt.millisecondsSinceEpoch <= lastClearedEpoch) {
                    continue;
                  }
                } catch (_) {}
              }

              list.add(n);
            }
          }

          setState(() {
            _remoteNotifications = list;
          });
        }
      }
    } catch (e) {
      debugPrint("[NotificationScreen] Error fetching history: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteSingleNotification(Map<String, dynamic> item) async {
    final id = item["_id"]?.toString() ?? "";
    final title = item['title']?.toString();
    final body = item['body']?.toString();
    final key = _buildNotificationKey(title, body);
    final legacyKey = "${title}_${item['handle'] ?? ''}_${item['status'] ?? ''}";

    setState(() {
      _dismissedKeys.add(key);
      _dismissedKeys.add(legacyKey);
      if (id.isNotEmpty) _dismissedKeys.add(id);
      _remoteNotifications.removeWhere((r) =>
          (r["_id"] != null && r["_id"].toString() == id) ||
          (_buildNotificationKey(r['title'], r['body']) == key));
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('dismissed_notification_keys', _dismissedKeys.toList());

    final localProvider = Provider.of<NotificationProvider>(context, listen: false);
    localProvider.removeNotificationWhere((l) =>
        _buildNotificationKey(l.title, l.body) == key ||
        (title != null && l.title == title && body != null && l.body == body));

    if (id.isNotEmpty) {
      http.delete(Uri.parse("${BackendConfig.baseUrl}/notifications/$id"))
          .catchError((_) => http.Response('', 500));
    }

    if (mounted) {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Notification deleted"),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _showClearAllDialog() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Clear All Notifications?"),
        content: const Text("Are you sure you want to delete all notifications? This cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEA0180),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Clear All", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final localProvider = Provider.of<NotificationProvider>(context, listen: false);
    localProvider.clearAll();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_cleared_notifications_at', DateTime.now().millisecondsSinceEpoch);

    setState(() {
      _remoteNotifications.clear();
    });

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final customerModel = Provider.of<CustomerModel>(context, listen: false);
    final customer = customerModel.customer ?? auth.customer;

    String? phone = customer?['phone']?.toString() ?? prefs.getString('fcm_last_phone');
    String? email = customer?['email']?.toString() ?? prefs.getString('fcm_last_email');
    String? customerId = customer?['id']?.toString() ?? prefs.getString('fcm_last_customer_id');

    final queryParams = <String, String>{};
    if (phone != null && phone.trim().isNotEmpty) queryParams['phone'] = phone.trim();
    if (email != null && email.trim().isNotEmpty) queryParams['email'] = email.trim();
    if (customerId != null && customerId.trim().isNotEmpty) queryParams['customerId'] = customerId.trim();

    if (queryParams.isNotEmpty) {
      final uri = Uri.parse("${BackendConfig.baseUrl}/notifications/clear/all")
          .replace(queryParameters: queryParams);
      http.delete(uri).catchError((_) => http.Response('', 500));
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("All notifications cleared"),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  String? _extractOrderNumber(dynamic val) {
    if (val == null) return null;
    final str = val.toString();
    final match = RegExp(r'#?(\d+)').firstMatch(str);
    return match != null ? "#${match.group(1)}" : null;
  }

  void _handleNotificationClick(BuildContext context, {
    required String? type,
    String? handle,
    String? titleArg,
    String? status,
    Map<String, dynamic>? rawItem,
  }) {
    final cleanType = (type ?? "").toLowerCase();
    final cleanStatus = (status ?? "").toLowerCase();

    // 1. Payment failed / abandoned -> Open Cart
    if (cleanStatus == 'payment_failed' || cleanType == 'cart') {
      Navigator.pushNamed(context, '/cart');
      return;
    }

    // 2. Order updates -> Open specific order
    if (cleanType == 'order' || cleanType == 'order_update' || titleArg != null || handle != null) {
      String? orderNum = _extractOrderNumber(titleArg);
      if (orderNum == null && rawItem != null) {
        orderNum = _extractOrderNumber(rawItem['title']) ?? _extractOrderNumber(rawItem['body']);
      }

      Navigator.pushNamed(
        context,
        '/orders',
        arguments: {
          "orderNumber": orderNum ?? titleArg,
          "orderId": handle,
        },
      );
      return;
    }

    // 3. Product deep-link
    if (cleanType == 'product' && handle != null && handle.isNotEmpty) {
      Navigator.pushNamed(
        context,
        '/product',
        arguments: handle,
      );
      return;
    }

    // 4. Collection deep-link
    if (cleanType == 'collection' && handle != null && handle.isNotEmpty) {
      Navigator.pushNamed(
        context,
        '/collection',
        arguments: {
          "collectionId": handle,
          "handle": handle,
          "title": titleArg ?? "Collection",
        },
      );
      return;
    }

    // Fallback
    Navigator.pushNamed(context, '/orders');
  }

  IconData _getStatusIcon(String? status) {
    switch (status?.toLowerCase()) {
      case 'order_placed':
      case 'order_confirmed':
        return Icons.check_circle_outline;
      case 'order_shipped':
      case 'out_for_delivery':
        return Icons.local_shipping_outlined;
      case 'order_delivered':
        return Icons.card_giftcard_outlined;
      case 'order_cancelled':
        return Icons.cancel_outlined;
      case 'order_refunded':
        return Icons.currency_rupee;
      case 'payment_failed':
        return Icons.error_outline;
      default:
        return Icons.notifications_none_outlined;
    }
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'order_placed':
      case 'order_confirmed':
        return const Color(0xFF2E7D32); // Green
      case 'order_shipped':
      case 'out_for_delivery':
        return const Color(0xFF0288D1); // Blue
      case 'order_delivered':
        return const Color(0xFFEA0180); // Brand Pink
      case 'order_cancelled':
        return const Color(0xFFD32F2F); // Red
      case 'order_refunded':
        return const Color(0xFFF57C00); // Amber/Orange
      case 'payment_failed':
        return const Color(0xFFE65100); // Dark Orange
      default:
        return const Color(0xFFEA0180); // Brand Pink
    }
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final notifDate = DateTime(dt.year, dt.month, dt.day);

    if (notifDate == today) {
      return "Today, ${DateFormat('hh:mm a').format(dt)}";
    } else if (today.difference(notifDate).inDays == 1) {
      return "Yesterday, ${DateFormat('hh:mm a').format(dt)}";
    } else {
      return DateFormat('d MMM, hh:mm a').format(dt);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localProvider = Provider.of<NotificationProvider>(context);
    final localNotifications = localProvider.notifications;

    final allItems = <Map<String, dynamic>>[];
    final seenKeys = <String>{};

    // 1. Add remote notifications from backend
    for (final r in _remoteNotifications) {
      final id = r['_id']?.toString() ?? "";
      final key = _buildNotificationKey(r['title'], r['body']);
      final legacyKey = "${r['title']}_${r['orderId'] ?? ''}_${r['status'] ?? ''}";

      if (_dismissedKeys.contains(id) || _dismissedKeys.contains(key) || _dismissedKeys.contains(legacyKey)) continue;

      if (!seenKeys.contains(key)) {
        seenKeys.add(key);
        DateTime dt = DateTime.now();
        if (r['sentAt'] != null) {
          try {
            dt = DateTime.parse(r['sentAt'].toString()).toLocal();
          } catch (_) {}
        }
        final isPaymentFailed = (r["status"]?.toString().toLowerCase() == "payment_failed");
        allItems.add({
          "_id": id,
          "title": r["title"] ?? "Order Update",
          "body": r["body"] ?? "",
          "time": dt,
          "type": isPaymentFailed ? "cart" : "order",
          "status": r["status"],
          "handle": r["orderId"]?.toString(),
          "titleArg": r["orderNumber"]?.toString() ?? _extractOrderNumber(r["title"]),
        });
      }
    }

    // 2. Add local notifications from Hive (skip if already loaded from backend)
    for (final l in localNotifications) {
      final key = _buildNotificationKey(l.title, l.body);
      if (_dismissedKeys.contains(key)) continue;

      if (!seenKeys.contains(key)) {
        seenKeys.add(key);
        final isPaymentFailed = (l.type?.toLowerCase() == "payment_failed") ||
            (l.title.toLowerCase().contains("failed"));
        allItems.add({
          "_id": "",
          "title": l.title,
          "body": l.body,
          "time": l.time,
          "type": isPaymentFailed ? "cart" : (l.type ?? "order"),
          "status": isPaymentFailed ? "payment_failed" : l.type,
          "handle": l.handle,
          "titleArg": l.titleArg ?? _extractOrderNumber(l.title),
        });
      }
    }

    allItems.sort((a, b) => (b["time"] as DateTime).compareTo(a["time"] as DateTime));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text(
          "Notifications",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        actions: [
          if (allItems.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.black54),
              tooltip: "Clear all notifications",
              onPressed: _showClearAllDialog,
            ),
        ],
      ),
      body: _isLoading && allItems.isEmpty
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFEA0180)),
            )
          : RefreshIndicator(
              color: const Color(0xFFEA0180),
              onRefresh: _fetchRemoteNotifications,
              child: allItems.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.7,
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEA0180).withValues(alpha: 0.08),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.notifications_none_outlined,
                                    size: 54,
                                    color: Color(0xFFEA0180),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  "No Notifications Yet",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF222222),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 40),
                                  child: Text(
                                    "We'll keep you updated here with order updates, delivery status, and exclusive offers.",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.black54,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                      itemCount: allItems.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = allItems[index];
                        final title = item["title"] as String;
                        final body = item["body"] as String;
                        final dt = item["time"] as DateTime;
                        final status = item["status"] as String?;
                        final icon = _getStatusIcon(status);
                        final iconColor = _getStatusColor(status);
                        final itemKey = "${item['_id']}_${title}_${index}";

                        return Dismissible(
                          key: Key(itemKey),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            decoration: BoxDecoration(
                              color: Colors.red.shade400,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  "Delete",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(width: 6),
                                Icon(Icons.delete_outline, color: Colors.white),
                              ],
                            ),
                          ),
                          onDismissed: (_) {
                            _deleteSingleNotification(item);
                          },
                          child: Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            elevation: 0.8,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                _handleNotificationClick(
                                  context,
                                  type: item["type"] as String?,
                                  handle: item["handle"] as String?,
                                  titleArg: item["titleArg"] as String?,
                                  status: item["status"] as String?,
                                  rawItem: item,
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: iconColor.withValues(alpha: 0.12),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(icon, color: iconColor, size: 22),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  title,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 15,
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                _formatDate(dt),
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey.shade500,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 5),
                                          Text(
                                            body,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey.shade700,
                                              height: 1.35,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.close,
                                        color: Colors.black26,
                                        size: 18,
                                      ),
                                      tooltip: "Delete notification",
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () {
                                        _deleteSingleNotification(item);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}