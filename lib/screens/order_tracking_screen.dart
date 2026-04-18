import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/order_tracking_service.dart';

class OrderTrackingScreen extends StatefulWidget {
  final Map order;

  const OrderTrackingScreen({super.key, required this.order});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    final orderId = widget.order['id']?.toString() ?? '';
    _future = OrderTrackingService.fetchTracking(orderId);
  }

  Future<void> _openTrackingUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Order Tracking',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      snapshot.error.toString(),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () {
                        setState(() {
                          final orderId = widget.order['id']?.toString() ?? '';
                          _future = OrderTrackingService.fetchTracking(orderId);
                        });
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final data = snapshot.data ?? const <String, dynamic>{};
          final trackingNumber = data['trackingNumber']?.toString();
          final courier = data['courier']?.toString();
          final currentStatus = data['currentStatus']?.toString();
          final estimatedDelivery = data['estimatedDelivery']?.toString();
          final shiprocketAvailable = data['shiprocket_available'] == true;
          final liveTrackingUrl = data['liveTrackingUrl']?.toString();

          final timeline = (data['timeline'] is List)
              ? List<Map<String, dynamic>>.from(data['timeline'])
              : const <Map<String, dynamic>>[];

          final trackingEvents = (data['trackingEvents'] is List)
              ? List<Map<String, dynamic>>.from(data['trackingEvents'])
              : const <Map<String, dynamic>>[];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _TrackingCard(
                orderName: data['orderId']?.toString(),
                courier: courier,
                trackingNumber: trackingNumber,
                currentStatus: currentStatus,
                estimatedDelivery: estimatedDelivery,
                shiprocketAvailable: shiprocketAvailable,
                onTrackTap: (liveTrackingUrl != null && liveTrackingUrl.isNotEmpty)
                    ? () => _openTrackingUrl(liveTrackingUrl)
                    : null,
              ),
              const SizedBox(height: 16),
              const Text(
                'Status',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _Timeline(steps: timeline),
              const SizedBox(height: 10),
              _TrackingEvents(events: trackingEvents),
            ],
          );
        },
      ),
    );
  }
}

class _TrackingCard extends StatelessWidget {
  final String? orderName;
  final String? courier;
  final String? trackingNumber;
  final String? currentStatus;
  final String? estimatedDelivery;
  final bool shiprocketAvailable;
  final VoidCallback? onTrackTap;

  const _TrackingCard({
    required this.orderName,
    required this.courier,
    required this.trackingNumber,
    required this.currentStatus,
    required this.estimatedDelivery,
    required this.shiprocketAvailable,
    required this.onTrackTap,
  });

  @override
  Widget build(BuildContext context) {
    String? estimatedLabel;
    if (estimatedDelivery == null || estimatedDelivery!.isEmpty) {
      estimatedLabel = "Calculating...";
    } else {
      try {
        final d = DateTime.parse(estimatedDelivery!);
        estimatedLabel = DateFormat('EEE, d MMM').format(d);
      } catch (_) {
        estimatedLabel = estimatedDelivery;
      }
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            orderName?.isNotEmpty == true ? 'Order: $orderName' : 'Order',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 10),
          if ((currentStatus ?? '').isNotEmpty) _kv('Current', currentStatus!),
          if ((courier ?? '').isNotEmpty)
            _kv('Courier', courier!),
          if ((trackingNumber ?? '').isNotEmpty)
            _kv('Tracking No.', trackingNumber!),
          _kv('Estimated Delivery', estimatedLabel ?? 'Calculating...'),
          if (!shiprocketAvailable)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Shiprocket tracking not available (showing Shopify status).',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
          if (onTrackTap != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onTrackTap,
                icon: const Icon(Icons.local_shipping_outlined),
                label: const Text('Live tracking'),
              ),
            ),
          ],
          if (onTrackTap == null && (courier ?? '').isEmpty && (trackingNumber ?? '').isEmpty)
            const Text('Tracking details not available yet.'),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: const TextStyle(color: Colors.black54)),
          Flexible(
            child: Text(
              v,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  final List<Map<String, dynamic>> steps;

  const _Timeline({required this.steps});

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) {
      return const Text('No tracking timeline available.');
    }

    int activeIndex = 0;
    for (int i = 0; i < steps.length; i++) {
      final done = steps[i]['done'] == true;
      if (!done) {
        activeIndex = i;
        break;
      }
      activeIndex = i;
    }

    return Column(
      children: List.generate(steps.length, (index) {
        final s = steps[index];
        final label = s['step']?.toString() ?? '';
        final completed = s['done'] == true;
        final isLast = index == steps.length - 1;
        return _TimelineRow(
          label: label,
          completed: completed,
          isActive: index == activeIndex && !completed,
          showConnector: !isLast,
        );
      }),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final String label;
  final bool completed;
  final bool isActive;
  final bool showConnector;

  const _TimelineRow({
    required this.label,
    required this.completed,
    required this.isActive,
    required this.showConnector,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = const Color(0xFFEA0180);
    final inactiveColor = Colors.grey.shade400;
    final borderColor = completed
        ? activeColor
        : (isActive ? activeColor : inactiveColor);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: completed ? activeColor : Colors.white,
                border: Border.all(color: borderColor, width: 2),
                shape: BoxShape.circle,
              ),
              child: completed
                  ? const Icon(Icons.check, size: 12, color: Colors.white)
                  : (isActive
                      ? Center(
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: activeColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        )
                      : null),
            ),
            if (showConnector)
              Container(
                width: 2,
                height: 36,
                color: completed ? activeColor : inactiveColor,
              ),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: completed ? FontWeight.w600 : FontWeight.w400,
                color: completed ? Colors.black : (isActive ? Colors.black : Colors.black54),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TrackingEvents extends StatelessWidget {
  final List<Map<String, dynamic>> events;

  const _TrackingEvents({required this.events});

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: const Text(
        'View Details',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      children: [
        if (events.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text('No scan history available.'),
          )
        else
          ...events.map((e) {
            final rawTime = e['time']?.toString();
            String timeLabel = '';
            if (rawTime != null && rawTime.isNotEmpty) {
              try {
                timeLabel = DateFormat('EEE, d MMM • h:mm a').format(DateTime.parse(rawTime));
              } catch (_) {
                timeLabel = rawTime;
              }
            }

            final location = e['location']?.toString() ?? '';
            final description = e['description']?.toString() ?? '';

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (timeLabel.isNotEmpty)
                      Text(
                        timeLabel,
                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    if (location.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          location,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    if (description.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(description),
                      ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}
