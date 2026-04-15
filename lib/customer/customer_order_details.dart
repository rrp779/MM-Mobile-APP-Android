import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../widgets/main_bottom_bar.dart';
import '../widgets/inner_page_app_bar.dart';
import '../screens/product_detail_screen.dart';
import '../widgets/app_icon.dart';
class OrderDetailsPage extends StatefulWidget {
  final Map order;

  const OrderDetailsPage({super.key, required this.order});

  @override
  State<OrderDetailsPage> createState() => _OrderDetailsPageState();
}

class _OrderDetailsPageState extends State<OrderDetailsPage> {

  int selectedIndex = 4;

  void _handleNavigation(int index) {
    // Add navigation logic if needed
  }

  @override
  Widget build(BuildContext context) {

    final items = widget.order['lineItems']['edges'];
    final address = widget.order['shippingAddress'] ?? {};

    final subtotal =
        double.tryParse(widget.order['subtotalPriceV2']?['amount'] ?? "0") ?? 0;

    final shipping =
        double.tryParse(widget.order['totalShippingPriceV2']?['amount'] ?? "0") ?? 0;

    final paymentMode =
    (widget.order['paymentGatewayNames'] != null &&
        widget.order['paymentGatewayNames'].isNotEmpty)
        ? widget.order['paymentGatewayNames'][0]
        : "N/A";

    final total =
        double.tryParse(widget.order['totalPriceV2']?['amount'] ?? "0") ?? 0;

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

    final fulfillmentStatus = widget.order['fulfillmentStatus'] ?? "";

    String statusText = "Processing";
    Color statusColor = Colors.orange;
    Color statusBg = Colors.orange.shade50;

    if (fulfillmentStatus == "FULFILLED") {
      statusText = "Delivered";
      statusColor = Colors.green;
      statusBg = Colors.green.shade50;
    } else if (fulfillmentStatus == "PARTIAL") {
      statusText = "Partially Delivered";
      statusColor = Colors.blue;
      statusBg = Colors.blue.shade50;
    } else if (fulfillmentStatus == "UNFULFILLED") {
      statusText = "Processing";
      statusColor = Colors.orange;
      statusBg = Colors.orange.shade50;
    }



    Widget _priceRow(
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

              Text(
                "$statusText On ${DateFormat('EEE, d MMM').format(DateTime.parse(widget.order['processedAt']))}",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              )
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

                      _priceRow(
                        "Total MRP",
                        "₹${totalMrp.toStringAsFixed(0)}",
                      ),

                      const SizedBox(height: 8),

                      _priceRow(
                        "Discounted Total MRP",
                        "₹${discountedMrp.toStringAsFixed(0)}",
                      ),

                      const SizedBox(height: 8),

                      _priceRow(
                        "Additional Discount",
                        "-₹${discount.toStringAsFixed(0)}",
                        valueColor: Colors.green,
                      ),

                      const SizedBox(height: 8),

                      /// SHIPPING
                      _priceRow(
                        "Shipping Charge",
                        shipping == 0 ? "Free" : "₹${shipping.toStringAsFixed(0)}",
                      ),

                      const Divider(height: 20),

                      _priceRow(
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