import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert' show jsonDecode;
import '../widgets/main_bottom_bar.dart';
import '../screens/product_detail_screen.dart';
import '../widgets/app_icon.dart';
import '../screens/invoice_preview_screen.dart';
import '../services/invoice_service.dart';
import '../screens/order_tracking_screen.dart';
import '../config/backend_config.dart';
class OrderDetailsPage extends StatefulWidget {
  final Map order;

  const OrderDetailsPage({super.key, required this.order});

  @override
  State<OrderDetailsPage> createState() => _OrderDetailsPageState();
}

class _OrderDetailsPageState extends State<OrderDetailsPage> {

  int selectedIndex = 4;
  bool _invoiceLoading = false;
  Map<String, dynamic>? _apiOrder;

  String _displayStatus(Map order) {
    final financial = (order['financialStatus'] ??
            order['financial_status'] ??
            order['displayFinancialStatus'] ??
            '')
        .toString()
        .trim()
        .toLowerCase();
    final fulfillment = (order['fulfillmentStatus'] ??
            order['fulfillment_status'] ??
            order['displayFulfillmentStatus'] ??
            '')
        .toString()
        .trim()
        .toLowerCase();
    final cancelReason = (order['cancelReason'] ?? order['cancel_reason'] ?? '').toString().trim();
    final cancelledAt = (order['cancelledAt'] ?? order['cancelled_at'] ?? '').toString().trim();

    if (cancelReason.isNotEmpty || cancelledAt.isNotEmpty) return 'Cancelled';
    if (financial == 'voided') return 'Cancelled';
    if (financial == 'refunded') return 'Refunded';
    if (financial == 'partially_refunded') return 'Partially Refunded';
    if (fulfillment == 'fulfilled') return 'Delivered';
    if (fulfillment == 'partial') return 'Partially Shipped';
    if (financial == 'paid' || financial == 'partially_paid') return 'Confirmed';
    if (financial == 'pending') return 'Pending Payment';
    return 'Processing';
  }

  String _resolveDisplayStatus(Map order) {
    final fromApi = (order['displayStatus'] ?? order['display_status'] ?? '').toString().trim();
    if (fromApi.isNotEmpty) return fromApi;
    return _displayStatus(order);
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'refunded':
        return Colors.red;
      case 'partially refunded':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'pending payment':
        return Colors.orange;
      case 'processing':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Widget _statusBadge(String status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  void _handleNavigation(int index) {
    // Add navigation logic if needed
  }

  Future<void> _openDownloadedInvoice() async {
    if (_invoiceLoading) return;

    final orderId = widget.order["id"]?.toString() ?? "";
    if (orderId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Order id not found for invoice")),
      );
      return;
    }

    setState(() {
      _invoiceLoading = true;
    });

    try {
      final bytes = await InvoiceService.fetchInvoicePdf(orderId);

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => InvoicePreviewScreen(order: widget.order, pdfBytes: bytes),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Invoice download failed (using in-app invoice): $e")),
      );

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => InvoicePreviewScreen(order: widget.order),
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _invoiceLoading = false;
      });
    }
  }

  Future<void> _openOrderTracking() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderTrackingScreen(order: widget.order),
      ),
    );
  }

  String _extractNumericId(String rawId) {
    String id = rawId.trim();
    if (id.contains('gid://shopify/Order/')) {
      id = id.replaceAll('gid://shopify/Order/', '');
    }
    if (id.contains('?')) {
      id = id.split('?')[0];
    }
    return id.trim();
  }

  Future<void> _loadOrderDetailsFromApi() async {
    try {
      final rawId = widget.order['id']?.toString() ?? '';
      final cleanId = _extractNumericId(rawId);
      if (cleanId.isEmpty) return;

      final encoded = Uri.encodeComponent(cleanId);
      final url = Uri.parse('${BackendConfig.baseUrl}/order/$encoded');
      final response = await http.get(url);
      if (response.statusCode != 200) return;

      final decoded = jsonDecode(response.body);
      if (!mounted) return;
      if (decoded is Map<String, dynamic>) {
        setState(() {
          _apiOrder = decoded;
        });
      }
    } catch (_) {
      // Best-effort only; UI falls back to Shopify Storefront fields.
    }
  }

  @override
  void initState() {
    super.initState();
    _loadOrderDetailsFromApi();
  }

  @override
  Widget build(BuildContext context) {

    final items = widget.order['lineItems']['edges'];
    final address = widget.order['shippingAddress'] ?? {};

    final shippingCharge = double.tryParse(
          _apiOrder?['shippingCharge']?.toString() ??
              widget.order['shippingCharge']?.toString() ??
              widget.order['totalShippingPriceV2']?['amount']?.toString() ??
              "0",
        ) ??
        0;
    final shippingTitle = (_apiOrder?['shippingTitle'] ?? widget.order['shippingTitle'] ?? 'Shipping Charge').toString();

    final total = double.tryParse(
          _apiOrder?['currentTotalPriceSet']?['shopMoney']?['amount']?.toString() ??
              widget.order['totalPriceV2']?['amount']?.toString() ??
              "0",
        ) ??
        0;

    final couponDiscountFromApi = double.tryParse(widget.order['couponDiscount']?.toString() ?? "0") ?? 0;
    final couponCode = (_apiOrder?['couponCode'] ?? widget.order['couponCode'])?.toString();
    final couponDiscountFromShopify = (() {
      final apps = widget.order['discountApplications'];
      if (apps is! Map) return 0.0;
      final edges = apps['edges'];
      if (edges is! List) return 0.0;
      double sum = 0;
      for (final e in edges) {
        if (e is! Map) continue;
        final node = e['node'];
        if (node is! Map) continue;
        final value = node['value'];
        if (value is! Map) continue;
        final amt = double.tryParse(value['amount']?.toString() ?? "0") ?? 0;
        sum += amt;
      }
      return sum;
    })();
    final couponDiscountFromBackend = double.tryParse(_apiOrder?['couponDiscount']?.toString() ?? "0") ?? 0;
    final couponDiscount = couponDiscountFromBackend > 0
        ? couponDiscountFromBackend
        : (couponDiscountFromApi > 0 ? couponDiscountFromApi : couponDiscountFromShopify);

    /// Calculate discount from compareAtPrice
    double totalMrp = 0;
    double discountedMrp = 0;

    for (var item in items) {
      final node = item['node'];

      final price = double.tryParse(
          node['variant']?['price']?['amount'] ?? "0") ??
          0;

      final compareAt = double.tryParse(
          node['variant']?['compareAtPrice']?['amount'] ?? "0") ??
          price;

      final quantity = node['quantity'] ?? 1;

      totalMrp += compareAt * quantity;
      discountedMrp += price * quantity;
    }

    final discount = totalMrp - discountedMrp;
    final productDiscount = double.tryParse(_apiOrder?['productDiscount']?.toString() ?? "") ??
        double.tryParse(widget.order['productDiscount']?.toString() ?? "") ??
        discount;

    final displayStatus = _resolveDisplayStatus(widget.order);



    Widget priceRow(
        String title,
        String value, {
          bool isBold = false,
          Color? valueColor,
        }) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight:
              isBold ? FontWeight.bold : FontWeight.w400,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight:
              isBold ? FontWeight.bold : FontWeight.w500,
              color: valueColor,
            ),
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,


        title: const Text(
          'Order Details',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),

        /// BACK ICON
        leading: IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: const SizedBox(
            width: 22,
            height: 22,
            child: AppIcon(
              isActive: false,
              outlinePath: 'assets/icons/ArrowLeft.svg',
              filledPath: 'assets/icons/ArrowLeft.svg',
            ),
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        actions: [
          IconButton(
            tooltip: "Invoice / Print",
            onPressed: _openDownloadedInvoice,
            icon: const Icon(Icons.receipt_long_outlined, color: Colors.black),
          ),
        ],

      ),

      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          /// ORDER ID
          Text(
            "Order ID: ${widget.order['name']}",
            style: const TextStyle(color: Colors.black),
          ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEA0180),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: _invoiceLoading ? null : _openDownloadedInvoice,
              icon: _invoiceLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.download_outlined),
              label: Text(_invoiceLoading ? "Preparing invoice..." : "Download Invoice"),
            ),
          ),

          const SizedBox(height: 10),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFEA0180),
                side: const BorderSide(color: Color(0xFFEA0180)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: _openOrderTracking,
              icon: const Icon(Icons.local_shipping_outlined),
              label: const Text("Track Order"),
            ),
          ),

          /// PRODUCT CARD
          for (var item in items)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [

                  /// IMAGE
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      item['node']?['variant']?['image']?['url'] ?? "",
                      height: 70,
                      width: 70,
                      fit: BoxFit.cover,
                    ),
                  ),

                  const SizedBox(width: 12),

                  /// PRODUCT INFO
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        /// PRODUCT TITLE
                        Text(
                          item['node']?['title'] ?? "Product",
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                        ),

                        /// VARIANT OPTIONS
                        if (item['node']?['variant']?['selectedOptions'] != null &&
                            item['node']['variant']['selectedOptions'].isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Wrap(
                              spacing: 6,
                              children: [
                                for (var option in item['node']['variant']['selectedOptions'])
                                  if (option['value'] != null &&
                                      option['value'] != "" &&
                                      option['value'] != "Default Title")
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        option['value'],
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    )
                              ],
                            ),
                          ),

                        const SizedBox(height: 10),

                        OutlinedButton(
                          onPressed: () {
                            final productId = item['node']?['variant']?['product']?['id'];

                            if (productId != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ProductDetailScreen(
                                    productId: productId,
                                  ),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Product not available"),
                                ),
                              );
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.pink,
                            side: const BorderSide(color: Colors.pink),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            minimumSize: const Size(0, 30), // height
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          child: const Text(
                            "Buy again",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      ],
                    ),
                  )
                ],
              ),
            ),

          SizedBox(
            width: double.infinity,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(
                100,
                    (index) => Container(
                  width: 2,
                  height: 2,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDADADA),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          /// DELIVERY STATUS
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayStatus,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "On ${DateFormat('EEE, d MMM').format(DateTime.parse(widget.order['processedAt']))}",
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),

              _statusBadge(displayStatus),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(
                100,
                    (index) => Container(
                  width: 2,
                  height: 2,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDADADA),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          /// DELIVERY DETAILS
          const Text(
            "Delivery details",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),

          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    SizedBox(
                      width: 16,
                      height: 16,
                      child: AppIcon(
                        isActive: false,
                        outlinePath: 'assets/icons/ProfileOutline.svg',
                        filledPath: 'assets/icons/ProfileOutline.svg',
                      ),
                    ),

                    const SizedBox(width: 8),

                    Expanded(
                      child: Text(
                        "${address['name'] ?? ""}",
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                  ],
                ),


                const SizedBox(height: 10),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    SizedBox(
                      width: 16,
                      height: 16,
                      child: AppIcon(
                        isActive: false,
                        outlinePath: 'assets/icons/HomeOutline.svg',
                        filledPath: 'assets/icons/HomeOutline.svg',
                      ),
                    ),

                    const SizedBox(width: 8),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                          Text(
                            "${address['address1'] ?? ""}, ${address['city'] ?? ""}",
                            style: const TextStyle(fontSize: 14),
                          ),

                          Text(
                            "${address['province'] ?? ""}, ${address['country'] ?? ""} - ${address['zip'] ?? ""}",
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black,
                            ),
                          ),

                        ],
                      ),
                    ),

                  ],
                ),
                const SizedBox(height: 6),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    SizedBox(
                      width: 16,
                      height: 16,
                      child: AppIcon(
                        isActive: false,
                        outlinePath: 'assets/icons/CallOutline.svg',
                        filledPath: 'assets/icons/CallOutline.svg',
                      ),
                    ),

                    const SizedBox(width: 8),

                    Expanded(
                      child: Text(
                        "${address['phone'] ?? ""}",
                        style: const TextStyle(
                          fontSize: 14,
                        ),
                      ),
                    ),

                  ],
                )
              ],
            ),
          ),

          const SizedBox(height: 24),

          /// ORDER PRICE
          const Text(
            "Order Price",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),

          const SizedBox(height: 10),

          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              children: [

                /// TOP PRICE SUMMARY
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [

                      Text(
                        "₹${total.toStringAsFixed(0)}",
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(width: 10),

                      if (discount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            "You saved ₹${discount.toStringAsFixed(0)}",
                            style: const TextStyle(
                              color: Colors.green,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                Divider(color: Colors.grey.shade300, height: 1),

                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [

                      priceRow(
                        "Total MRP",
                        "₹${totalMrp.toStringAsFixed(0)}",
                      ),

                      const SizedBox(height: 8),

                      priceRow(
                        "Discounted Total MRP",
                        "₹${discountedMrp.toStringAsFixed(0)}",
                      ),

                      const SizedBox(height: 8),

                      priceRow(
                        "Additional Discount",
                        "-₹${productDiscount.toStringAsFixed(0)}",
                        valueColor: Colors.green,
                      ),

                      const SizedBox(height: 8),

                      if (couponDiscount > 0) ...[
                        priceRow(
                          couponCode != null && couponCode.trim().isNotEmpty
                              ? "Coupon ($couponCode)"
                              : "Coupon Discount",
                          "-₹${couponDiscount.toStringAsFixed(0)}",
                          valueColor: Colors.green,
                        ),
                        const SizedBox(height: 8),
                      ],

                      /// SHIPPING
                      priceRow(
                        shippingTitle,
                        shippingCharge == 0
                            ? "Free"
                            : "₹${shippingCharge.toStringAsFixed(0)}",
                        valueColor: shippingCharge == 0 ? Colors.green : null,
                      ),

                      const Divider(height: 20),

                      priceRow(
                        "Order Total",
                        "₹${total.toStringAsFixed(0)}",
                        isBold: true,
                      ),

                      const SizedBox(height: 10),

                      /// PAYMENT MODE
                    //  _priceRow(
                       // "Payment Mode",
                      //  paymentMode,
                    //  ),

                    ],
                  ),
                )
              ],
            ),
          )
        ],
      ),

      /// BOTTOM BAR
      bottomNavigationBar: MainBottomBar(
        selectedIndex: selectedIndex,
        onItemSelected: (index) {
          setState(() {
            selectedIndex = index;
          });
          _handleNavigation(index);
        },
      ),
    );
  }
}
