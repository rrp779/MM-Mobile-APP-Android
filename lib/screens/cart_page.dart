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
      bottomNavigationBar: _checkoutSection(context, cart),
      body: cart.lines.isEmpty
          ? const Center(child: Text("Your bag is empty"))
          : ListView(
              padding: const EdgeInsets.only(bottom: 160),
              children: [
                ...cart.lines.map(
                  (line) => _modernCartItem(context, line),
                ),
                const SizedBox(height: 20),
              ],
            ),
    );
  }

  Widget _modernCartItem(BuildContext context, Map line) {
    final cart = context.read<CartProvider>();

    final merchandise = line['merchandise'];
    final product = merchandise['product'];
    final qty = line['quantity'];
    final lineId = line['id'];
    final lineDiscountAllocations = (line['discountAllocations'] as List?)
            ?.map((e) => e as Map<String, dynamic>)
            .toList() ??
        [];
    final double lineDiscount =
        lineDiscountAllocations.fold(0.0, (double sum, allocation) {
      return sum +
          (double.tryParse(
                  allocation['discountedAmount']?['amount']?.toString() ??
                      "0") ??
              0);
    });

    final price = double.parse(merchandise['price']['amount']);
    final compareAtRaw = merchandise['compareAtPrice']?['amount'];
    final double? compareAt =
        compareAtRaw != null ? double.tryParse(compareAtRaw) : null;
    final bool hasDiscount = compareAt != null && compareAt > price;
    final int discountPercent = hasDiscount
        ? (((compareAt! - price) / compareAt) * 100).round()
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                        formatPrice(compareAt!),
                        style: const TextStyle(
                          decoration: TextDecoration.lineThrough,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "($discountPercent% Off)",
                        style: const TextStyle(color: Colors.green),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                if (lineDiscount > 0) ...[
                  Text(
                    "Bundle Discount: -${formatPrice(lineDiscount)}",
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                ] else
                  const SizedBox(height: 12),
                Row(
                  children: [
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
                            onTap: () {
                              cart.updateQuantity(
                                lineId: lineId,
                                quantity: qty + 1,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
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
            fontWeight: isBold ? FontWeight.bold : FontWeight.w400,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _qtyButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, size: 18),
      ),
    );
  }

  Widget _checkoutSection(BuildContext context, CartProvider cart) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              blurRadius: 10,
              offset: Offset(0, -8),
              color: Colors.black12,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
                    const Icon(Icons.celebration, color: Colors.green),
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
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  _priceRow("Total MRP", formatPrice(cart.totalMrp)),
                  const SizedBox(height: 6),
                  if (cart.productPriceDiscount > 0) ...[
                    _priceRow(
                      "Product Discount",
                      "-${formatPrice(cart.productPriceDiscount)}",
                      valueColor: Colors.green,
                    ),
                    const SizedBox(height: 6),
                  ],
                  if (cart.cartDiscountTotal > 0) ...[
                    _priceRow(
                      "Bundle Discount",
                      "-${formatPrice(cart.cartDiscountTotal)}",
                      valueColor: Colors.green,
                    ),
                    const SizedBox(height: 6),
                  ],
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
                onPressed: cart.lines.isEmpty
                    ? null
                    : () async {
                        final prefs = await SharedPreferences.getInstance();
                        String? customer = prefs.getString("customer");

                        if (customer == null) {
                          final result = await showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => const LoginBottomSheet(),
                          );
                          if (result != true) return;
                        }

                        // ✅ Navigate to in-app CheckoutScreen
                        final cartItems = cart.lines.map((line) {
                          final merchandise = line['merchandise'];
                          return {
                            "variant_id": merchandise['id'],
                            "title": merchandise['product']['title'],
                            "image": merchandise['image']?['url'] ?? '',
                            "price": double.tryParse(
                                    merchandise['price']['amount'].toString()) ??
                                0,
                            "qty": line['quantity'],
                          };
                        }).toList();

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CheckoutScreen(
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
            ),
          ],
        ),
      ),
    );
  }
}
