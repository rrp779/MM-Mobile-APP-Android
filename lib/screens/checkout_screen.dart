import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:provider/provider.dart';
import '../customer/customer_model.dart';
import '../customer/customer_orders.dart';
import '../widgets/address_selector_sheet.dart';
import '../widgets/coupon_bottom_sheet.dart';
import '../screens/login_screen.dart';
import '../config/backend_config.dart';
import '../providers/cart_provider.dart';

class CheckoutScreen extends StatefulWidget {

  final List cartItems;
  final double totalMrp;
  final double totalDiscount;
  final double totalAmount;

  const CheckoutScreen({
    super.key,
    required this.cartItems,
    required this.totalMrp,
    required this.totalDiscount,
    required this.totalAmount,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {

  String? userName;
  bool isLoadingUser = true;

  Map? selectedAddress;

  late Razorpay _razorpay;

  String formatPrice(double amount) {
    return "₹ ${amount.toStringAsFixed(2)}";
  }

  String get razorpayLogoUrl {
    return "https://www.makeupmystery.in/cdn/shop/files/update-faviconlogo.png";
  }

  TextEditingController couponController = TextEditingController();

  @override
  void initState() {
    super.initState();

    _razorpay = Razorpay();

    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, handleExternalWallet);

    checkLogin();
  }

  /// LOGIN CHECK
  Future<void> checkLogin() async {

    final prefs = await SharedPreferences.getInstance();
    String? customer = prefs.getString("customer");

    if (customer == null) {

      if (!mounted) return;

      final result = await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useRootNavigator: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(20),
          ),
        ),
        builder: (_) {
          return const CustomerLoginRegister();
        },
      );

      /// After login reload checkout
      if (result == true) {
        checkLogin();
      }

      return;
    }

    final data = jsonDecode(customer);

    setState(() {
      userName = data["firstName"] ?? data["name"] ?? "Customer";
      isLoadingUser = false;
    });

    final cartProvider = context.read<CartProvider>();
    await cartProvider.updateBuyerIdentity(data["accessToken"]);

    loadDefaultAddress(data["accessToken"]);
  }

  /// LOAD SHOPIFY DEFAULT ADDRESS
  Future<void> loadDefaultAddress(String accessToken) async {

    final client = GraphQLProvider.of(context).value;

    final result = await client.query(
      QueryOptions(
        document: gql(r'''
          query customer($accessToken: String!) {
            customer(customerAccessToken: $accessToken) {
              defaultAddress {
                id
                name
                address1
                city
                phone
                zip
              }
            }
          }
        '''),
        variables: {
          "accessToken": accessToken
        },
        fetchPolicy: FetchPolicy.networkOnly,
        cacheRereadPolicy: CacheRereadPolicy.ignoreAll,
        errorPolicy: ErrorPolicy.all,
      ),
    );

    if (result.data?["customer"]?["defaultAddress"] != null) {
      setState(() {
        selectedAddress = result.data!["customer"]["defaultAddress"];
      });
    }
  }

  /// OPEN ADDRESS SELECTOR
  Future<void> selectAddress() async {

    final address = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => AddressSelectorSheet(
        selectedId: selectedAddress?["id"],
      ),
    );

    if (address != null) {
      setState(() {
        selectedAddress = address;
      });
    }
  }

  void applySelectedCoupon(dynamic coupon) async {
    final code = coupon is Map
        ? coupon['code']?.toString() ?? ''
        : coupon.toString();

    if (code.trim().isEmpty) return;

    final cartProvider = context.read<CartProvider>();
    final error = await cartProvider.applyDiscountCode(code);

    if (!mounted) return;

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
    } else {
      final appliedCode = cartProvider.appliedCoupon ?? code.toUpperCase();
      couponController.text = appliedCode;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Coupon $appliedCode applied! You save ${formatPrice(cartProvider.couponDiscount)}",
          ),
        ),
      );
    }
  }

  /// OPEN RAZORPAY
  Future<void> openCheckout() async {

    if (selectedAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please select delivery address"))
      );
      return;
    }

    /// ✅ USE SAME CALCULATION
    final cartProvider = context.read<CartProvider>();
    double subtotalAfterDiscount = widget.totalAmount - cartProvider.couponDiscount;
    double shipping = subtotalAfterDiscount < 1500 ? 80 : 0;
    double finalAmount = subtotalAfterDiscount + shipping;

    int amountInPaise = (finalAmount * 100).toInt();

    final customer = context.read<CustomerModel>().customer;

    try {
      final response = await http.post(
        Uri.parse("${BackendConfig.baseUrl}/payment/create-order"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "amount": amountInPaise,
          "cart": widget.cartItems.map((item) => {
            "variant_id": item["variant_id"],  // MUST exist
            "quantity": item["qty"],           // FIX HERE
            "price": item["price"],
          }).toList(),
          "total_mrp": widget.totalMrp,
          "discount": widget.totalDiscount,
          "coupon_discount": cartProvider.couponDiscount,
          "shipping": shipping,
          "email": customer?["email"] ?? "",
          "phone": selectedAddress?["phone"] ?? "",
        }),
      );

      if (response.statusCode != 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Unable to start payment. Please try again.")),
        );
        return;
      }

      final data = jsonDecode(response.body);
      if (data == null || data["id"] == null || data["amount"] == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Payment init failed. Please try again.")),
        );
        return;
      }

      final razorpayKeyId = (data["key_id"] ?? data["key"] ?? "").toString().trim();
      if (razorpayKeyId.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Payment config missing. Please try again later.")),
        );
        return;
      }

      var options = {
        'key': razorpayKeyId,
        'amount': data['amount'],
        'order_id': data['id'],
        'name': 'Makeup Mystery India',
        'description': 'Order Payment',
        'image': razorpayLogoUrl,
        'timeout': 300,
        'prefill': {
          'contact': selectedAddress?["phone"] ?? "",
          'email': customer?["email"] ?? "",
        },
      };

      _razorpay.open(options);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Backend not reachable. Please check backend URL or internet."),
        ),
      );
    }
  }

  void showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [

                /// ✅ ICON
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.green,
                    size: 40,
                  ),
                ),

                const SizedBox(height: 16),

                /// TITLE
                const Text(
                  "Order Placed!",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                /// SUBTITLE
                const Text(
                  "Your order has been placed successfully 🎉",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),

                const SizedBox(height: 20),

                /// BUTTON
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEA0180),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(context); // close dialog

                      /// ✅ REDIRECT TO ORDERS PAGE
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CustomerOrders(),
                        ),
                            (route) => false,
                      );
                    },
                    child: const Text(
                      "Continue Shopping",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  /// PAYMENT SUCCESS
  void handlePaymentSuccess(PaymentSuccessResponse response) async {
    final cartProvider = context.read<CartProvider>();
    try {

    if (selectedAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Address missing")),
      );
      return;
    }

    double subtotalAfterDiscount = widget.totalAmount - cartProvider.couponDiscount;
    double shipping = subtotalAfterDiscount < 1500 ? 80 : 0;
    double finalAmount = subtotalAfterDiscount + shipping;
    final appliedCoupon = (cartProvider.appliedCoupon ?? couponController.text)
        .toString()
        .trim()
        .toUpperCase();

    /// ✅ FIX: Safe name parsing
    String fullName = selectedAddress?["name"]?.toString() ?? "Customer";
    List<String> nameParts = fullName.split(" ");

    String firstName = nameParts.isNotEmpty ? nameParts.first : "Customer";
    String lastName = nameParts.length > 1 ? nameParts.last : "";

    /// ✅ FIX: Get email from customer model (NOT address)
    final customer = context.read<CustomerModel>().customer;
    String email = customer?["email"] ?? "";

    // Show blocking loader
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const PopScope(
        canPop: false,
        child: Center(
          child: CircularProgressIndicator(
            color: Color(0xFFEA0180),
          ),
        ),
      ),
    );

    final verify = await http.post(
      Uri.parse("${BackendConfig.baseUrl}/payment/verify"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "razorpay_order_id": response.orderId,
        "razorpay_payment_id": response.paymentId,
        "razorpay_signature": response.signature,

        "first_name": firstName,
        "last_name": lastName,

        "email": email,
        "phone": selectedAddress?["phone"] ?? "",

        "address1": selectedAddress?["address1"] ?? "",
        "city": selectedAddress?["city"] ?? "",
        "state": "Gujarat",
        "pincode": selectedAddress?["zip"] ?? "",

        "amount": (finalAmount * 100).toInt(),

        "couponCode": appliedCoupon.isEmpty ? null : appliedCoupon,
        "couponDiscount": cartProvider.couponDiscount,
        "shippingAmount": shipping,
        "totalMrp": widget.totalMrp,
        "productDiscount": widget.totalDiscount,
      }),
    );

    if (context.mounted) {
      Navigator.pop(context); // Dismiss blocking loader
    }

    final data = jsonDecode(verify.body);

    if (data["success"]) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove("cart"); // 🔥 important
      cartProvider.resetCartState();
      couponController.clear();
      showSuccessDialog();
    } else {

      final details = data["details"];
      final detailsText = (details == null)
          ? null
          : (details is String)
              ? details
              : details.toString();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            detailsText?.isNotEmpty == true
                ? detailsText!
                : (data["message"] ?? "Verification Failed"),
          ),
        ),
      );

    }
    } catch (_) {
      if (context.mounted) {
        Navigator.pop(context); // Dismiss blocking loader if open
      }
      cartProvider.resetCartState(); // Clear cart anyway since they paid
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Payment completed, but order confirmation failed. Please contact support with your payment ID.",
          ),
        ),
      );
    }
  }

  void handlePaymentError(PaymentFailureResponse response) {
    if (!mounted) return;
    final msg = (response.message?.isNotEmpty ?? false)
        ? response.message!
        : "Payment failed or timed out. If amount was deducted, it will be refunded in 5-7 working days.";
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  void handleExternalWallet(ExternalWalletResponse response) {
    print("Wallet ${response.walletName}");
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    final cartProvider = context.watch<CartProvider>();
    final customer = context.watch<CustomerModel>().customer;
    final userName = customer?['firstName'] ?? "Customer";
    /// ✅ GLOBAL CALCULATION (IMPORTANT)
    double subtotalAfterDiscount = widget.totalAmount - cartProvider.couponDiscount;
    double shipping = subtotalAfterDiscount < 1500 ? 80 : 0;
    double finalAmount = subtotalAfterDiscount + shipping;


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
    if (isLoadingUser) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    Future<void> openCouponSheet() async {
      final selectedCoupon = await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useRootNavigator: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => CouponBottomSheet(
          cartAmount: widget.totalAmount,
        ),
      );
      if (selectedCoupon != null) {
        applySelectedCoupon(selectedCoupon);
      }
    }
    void applyManualCoupon() async {
      String code = couponController.text.trim().toUpperCase();
      if (code.isEmpty) return;
      applySelectedCoupon(code);
    }
    return Scaffold(
      backgroundColor: const Color(0xfff6f6f6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Checkout",
              style: TextStyle(fontSize: 16),
            ),
            Text(
              "Hello, $userName",
              style: const TextStyle(
                fontSize: 13,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                /// ADDRESS CARD
                GestureDetector(
                  onTap: selectAddress,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on_outlined),
                        const SizedBox(width: 10),
                        Expanded(
                          child: selectedAddress == null
                              ? const Text(
                            "Select Delivery Address",
                            style: TextStyle(fontWeight: FontWeight.w600),
                          )
                              : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [

                              Text(
                                selectedAddress!["name"] ?? "",
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "${selectedAddress!["address1"]}, ${selectedAddress!["city"]}",
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios, size: 16)
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                /// PRODUCT LIST
                Column(
                  children: widget.cartItems.map((item) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [

                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              item["image"],
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                            ),
                          ),

                          const SizedBox(width: 10),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [

                                Text(item["title"],
                                    style: const TextStyle(fontSize: 12)),

                                Text("Qty: ${item["qty"]}",
                                    style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12)),
                              ],
                            ),
                          ),

                          const SizedBox(width: 20),

                          Text(
                            formatPrice(finalAmount),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          )
                        ],
                      ),
                    );

                  }).toList(),
                ),

                const SizedBox(height: 16),

                /// COUPON SECTION
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Apply Coupon",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      /// INPUT + APPLY
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: couponController,
                              decoration: InputDecoration(
                                hintText: "Enter coupon code",
                                hintStyle: TextStyle(
                                  fontSize: 14, // 👈 change size here
                                  color: Colors.grey,
                                ),
                                contentPadding:
                                const EdgeInsets.symmetric(horizontal: 10),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEA0180),
                            ),
                            onPressed: () {
                              applyManualCoupon();
                            },
                            child: const Text(
                              "Apply",
                              style: TextStyle(color: Colors.white),
                            ),
                          )
                        ],
                      ),

                      const SizedBox(height: 10),

                      /// VIEW COUPONS LINK
                      GestureDetector(
                        onTap: openCouponSheet,
                        child: const Text(
                          "View Available Coupons",
                          style: TextStyle(
                            color: Color(0xFFEA0180),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),

                      /// APPLIED COUPON
                      if (cartProvider.appliedCoupon != null)
                        Container(
                          margin: const EdgeInsets.only(top: 10),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Applied: ${cartProvider.appliedCoupon}",
                                style: const TextStyle(color: Colors.green),
                              ),
                              GestureDetector(
                                onTap: () async {
                                  await cartProvider.removeDiscountCode();
                                  couponController.clear();
                                },
                                child: const Icon(Icons.close, size: 18),
                              )
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                /// PRICE DETAILS
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [

                      _priceRow("Total MRP", formatPrice(widget.totalMrp)),

                      const SizedBox(height: 8),

                      _priceRow(
                        "Discount",
                        "-${formatPrice(widget.totalDiscount)}",
                        valueColor: Colors.green,
                      ),

                      if (cartProvider.couponDiscount > 0) ...[
                        const SizedBox(height: 8),
                        _priceRow(
                          "Additional Discount",
                          "-${formatPrice(cartProvider.couponDiscount)}",
                          valueColor: Colors.green,
                        ),
                      ],

                      const SizedBox(height: 8),

                      /// 🚚 SHIPPING
                      _priceRow(
                        "Shipping",
                        shipping == 0 ? "FREE" : formatPrice(shipping),
                        valueColor: shipping == 0 ? Colors.green : null,
                      ),

                      if (cartProvider.couponDiscount > 0) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "🎉 You saved ${formatPrice(cartProvider.couponDiscount)}",
                            style: const TextStyle(color: Colors.green),
                          ),
                        ),
                      ],

                      const Divider(height: 24),

                      _priceRow(
                        "Total Amount",
                        formatPrice(finalAmount),
                        isBold: true,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 100),

              ],
            ),
          ),

          /// PAY BUTTON
          SafeArea(
            top: false, // 👈 only apply bottom safe area
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    blurRadius: 10,
                    offset: const Offset(0, -15),
                    color: Colors.white10,
                  )
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Total Payable"),
                        Text(
                          formatPrice(finalAmount),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEA0180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 30,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: openCheckout,
                    child: const Text(
                      "Pay Now",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
