import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import 'checkout_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/login_bottom_sheet.dart';

class CartPage extends StatelessWidget {
  const CartPage({super.key});
  String formatPrice(double amount) {
    return "₹ ${amount.toStringAsFixed(2)}";
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: Text(
          "My Bag (${cart.totalQuantity} items)",
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.black,
             fontSize: 16,
          ),
        ),
      ),
      bottomNavigationBar:
          cart.lines.isEmpty ? null : _checkoutSection(context, cart),
      body: cart.isLoading && cart.lines.isEmpty
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFEA0180),
              ),
            )
          : cart.lines.isEmpty
              ? RefreshIndicator(
                  onRefresh: () => cart.fetchCart(),
                  color: const Color(0xFFEA0180),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Container(
                      height: MediaQuery.of(context).size.height * 0.7,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 88,
                            height: 88,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFDE7F3),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.shopping_bag_outlined,
                              size: 46,
                              color: Color(0xFFEA0180),
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            "Your Bag is Empty",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E1E2D),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Looks like you haven't added anything to your bag yet. Explore our collections and discover something you love!",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pushNamedAndRemoveUntil(
                                context,
                                '/home',
                                (route) => false,
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEA0180),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 28,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              "Start Shopping",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => cart.fetchCart(),
                  color: const Color(0xFFEA0180),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 160),
                    children: [
                      /// 🔹 CART ITEMS
                      ...cart.lines.map(
                        (line) => _modernCartItem(context, line),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
    );
  }

  // ============================================================
  // 🔥 MODERN CART ITEM
  // ============================================================

  Widget _modernCartItem(BuildContext context, Map line) {
    final cart = context.read<CartProvider>();

    final merchandise = line['merchandise'];
    final product = merchandise['product'];
    final int qty = (line['quantity'] as num?)?.toInt() ?? 1;
    final lineId = line['id']?.toString() ?? "";
    final int? quantityAvailable =
        merchandise['quantityAvailable'] as int?;
    final bool isMaxStockReached =
        quantityAvailable != null && qty >= quantityAvailable;

    final price =
    double.parse(merchandise['price']['amount']);

    final compareAtRaw =
    merchandise['compareAtPrice']?['amount'];

    final double? compareAt =
    compareAtRaw != null
        ? double.tryParse(compareAtRaw)
        : null;

    final bool hasDiscount =
        compareAt != null && compareAt > price;

    final int discountPercent = hasDiscount
        ? (((compareAt - price) / compareAt) * 100)
        .round()
        : 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFEFEFEF)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          /// IMAGE
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              merchandise['image']?['url'] ?? '',
              width: 80,
              height: 80,
              fit: BoxFit.cover,
            ),
          ),

          const SizedBox(width: 12),

          /// DETAILS
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [

                Text(
                  product['title'],
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),

                const SizedBox(height: 6),

                /// PRICE ROW
                Row(
                  children: [
                    Text(
                      formatPrice(price),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (hasDiscount) ...[
                      const SizedBox(width: 6),
                      Text(
                        formatPrice(compareAt),
                        style: const TextStyle(
                          decoration:
                          TextDecoration.lineThrough,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "($discountPercent% Off)",
                        style: const TextStyle(
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ],
                ),

                /// ⚠️ STOCK WARNING LABEL
                if (isMaxStockReached) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 14, color: Colors.red.shade700),
                      const SizedBox(width: 4),
                      Text(
                        "Max stock reached ($quantityAvailable in stock)",
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ] else if (quantityAvailable != null && quantityAvailable <= 5) ...[
                  const SizedBox(height: 6),
                  Text(
                    "Only $quantityAvailable left in stock",
                    style: TextStyle(
                      color: Colors.orange.shade800,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                /// QTY STEPPER
                Row(
                  children: [

                    /// 🔹 QTY STEPPER
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _qtyButton(
                            icon: Icons.remove,
                            onTap: () {
                              if (qty > 1) {
                                cart.updateQuantity(
                                  lineId: lineId,
                                  quantity: qty - 1,
                                );
                              }
                            },
                          ),
                          Padding(
                            padding:
                            const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              "$qty",
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                          _qtyButton(
                            icon: Icons.add,
                            enabled: !isMaxStockReached,
                            onTap: () async {
                              if (isMaxStockReached) {
                                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      "Only $quantityAvailable item${quantityAvailable == 1 ? '' : 's'} available in stock",
                                      style: const TextStyle(fontWeight: FontWeight.w500),
                                    ),
                                    backgroundColor: const Color(0xFFE11D48),
                                    behavior: SnackBarBehavior.floating,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                                return;
                              }
                              final error = await cart.updateQuantity(
                                lineId: lineId,
                                quantity: qty + 1,
                              );
                              if (error != null && context.mounted) {
                                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      error,
                                      style: const TextStyle(fontWeight: FontWeight.w500),
                                    ),
                                    backgroundColor: const Color(0xFFE11D48),
                                    behavior: SnackBarBehavior.floating,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 16),

                    /// 🔹 REMOVE ICON
                    InkWell(
                      onTap: () async {
                        await cart.removeItem(lineId);
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),

              ],
            ),
          ),
        ],
      ),
    );
  }
  // ============================================================
  // 🔥 Price
  // ============================================================
  Widget _priceRow(
      String title,
      String value, {
        bool isBold = false,
        Color? valueColor,
      }) {
    return Row(
      mainAxisAlignment:
      MainAxisAlignment.spaceBetween,
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


  // ============================================================
  // 🔥 QTY BUTTON
  // ============================================================

  Widget _qtyButton({
    required IconData icon,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          icon,
          size: 18,
          color: enabled ? Colors.black : Colors.grey.shade400,
        ),
      ),
    );
  }

  // ============================================================
  // 🔥 SECTION HEADER
  // ============================================================

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: 16),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }


  // ============================================================
  // 🔥 CHECKOUT SECTION
  // ============================================================

  Widget _checkoutSection(

      BuildContext context, CartProvider cart) {
    return SafeArea(
        top: false, // 👈 only bottom safe area
        child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
    decoration: const BoxDecoration(
    color: Colors.white,
    boxShadow: [
    BoxShadow(
      blurRadius: 10,
      offset: const Offset(0, -8),
      color: Colors.black12,
    ),
    ],
    ),
    child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [


          /// 🔹 SAVINGS BANNER
          if (cart.totalDiscount > 0)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.celebration,
                      color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Woohoo! You save ${formatPrice(cart.totalDiscount)} on this order",
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          /// 🔹 PRICE BREAKDOWN
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.grey.shade200,
              ),
            ),
            child: Column(
              children: [

                _priceRow(
                  "Total MRP",
                  formatPrice(cart.totalMrp),
                ),

                const SizedBox(height: 6),

                _priceRow(
                  "Discount",
                  "-${formatPrice(cart.totalDiscount)}",
                  valueColor: Colors.green,
                ),
                const Divider(height: 20),

                _priceRow(
                  "Total",
                  formatPrice(cart.totalSellingPrice),
                  isBold: true,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          /// 🔹 CHECKOUT BUTTON
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEA0180),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: cart.checkoutUrl == null
                  ? null
                  : () async {

                final prefs = await SharedPreferences.getInstance();
                String? customer = prefs.getString("customer");

                /// 🚨 SHOW LOGIN BOTTOM SHEET
                if (customer == null) {

                  final result = await showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const LoginBottomSheet(),
                  );

                  /// ❌ User closed sheet
                  if (result != true) return;

                  customer = prefs.getString("customer");
                }

                if (customer != null) {
                  final customerData = jsonDecode(customer);
                  await cart.updateBuyerIdentity(customerData["accessToken"]);
                }

                /// ✅ CONTINUE CHECKOUT (same as your code)
                final cartItems = cart.lines.map((line) {

                  final merchandise = line['merchandise'];
                  final product = merchandise['product'];

                  return {
                    "title": product['title'],
                    "price": double.parse(merchandise['price']['amount']).round(),
                    "qty": line['quantity'],
                    "image": merchandise['image']?['url'] ?? "",
                    "variant_id": merchandise['id'],        // ✅ correct key
                    "productId": product['id'],
                    "handle": product['handle'] ?? "",
                  };

                }).toList();

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CheckoutScreen(
                      cartItems: cartItems,
                      totalMrp: cart.totalMrp,
                      totalDiscount: cart.totalDiscount,
                      totalAmount: cart.totalSellingPrice,
                    ),
                  ),
                );
              },
              child: Text(
                "Checkout ${formatPrice(cart.totalSellingPrice)}",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          )
        ],
      ),
        )
    );
  }

}
