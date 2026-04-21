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

  double calculateShipping(double subtotal) {
    if (subtotal >= 1500) return 0;
    return 80;
  }

  String? appliedCoupon;
  double couponDiscount = 0;
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

  void applySelectedCoupon(Map coupon) {
    final endsAtRaw = coupon["ends_at"]?.toString();
    if (endsAtRaw != null && endsAtRaw.trim().isNotEmpty) {
      try {
        final endsAt = DateTime.parse(endsAtRaw).toLocal();
        if (endsAt.isBefore(DateTime.now())) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("This coupon has expired")),
          );
          return;
        }
      } catch (_) {}
    }

    final type = coupon["discount_type"];
    final value = double.parse(coupon["value"].toString().replaceAll("-", ""));

    final minimum = coupon["minimum"] != null
        ? double.tryParse(coupon["minimum"].toString())
        : null;

    if (minimum != null && widget.totalAmount < minimum) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Minimum order ₹${minimum.toInt()} required")),
      );
      return;
    }

    double discount = 0;

    if (type == "fixed_amount") {
      discount = value;
    } else if (type == "percentage") {
      if (type == "percentage") {

        /// 🎁 FREE GIFT CASE
        if (value == 100) {
          discount = 0; // ❗ DO NOT DISCOUNT PRICE

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Free gift will be added to your order 🎁")),
          );

        } else {
          discount = (widget.totalAmount * value) / 100;
        }
      }
    }

    setState(() {
      appliedCoupon = coupon["code"];
      couponDiscount = discount;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Coupon ${coupon["code"]} applied")),
    );
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
    double subtotalAfterDiscount = widget.totalAmount - couponDiscount;
    double shipping = calculateShipping(subtotalAfterDiscount);
    double finalAmount = subtotalAfterDiscount + shipping;

    int amountInPaise = (finalAmount * 100).toInt();

    final customer = context.read<CustomerModel>().customer;

    final response = await http.post(
      Uri.parse("${BackendConfig.baseUrl}/payment/create-order"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "amount": amountInPaise,
        "cart": widget.cartItems.map((item) => {
          "variant_id": item["variant_id"],  // MUST exist
          "quantity": item["qty"],           // FIX HERE
          "price": item["price"] ?? 0,
        }).toList(),
        "total_mrp": widget.totalMrp,
        "discount": widget.totalDiscount,
        "coupon_discount": couponDiscount,
        "shippingAmount": shipping,
        "email": customer?["email"] ?? "",
        "phone": selectedAddress?["phone"] ?? "",
      }),
    );

    final data = jsonDecode(response.body);

    var options = {
      'key': 'rzp_test_SNpvRm3HgoZeEj',
      'amount': data['amount'],
      'order_id': data['id'],
      'name': 'Makeup Mystery India',
      'description': 'Order Payment',
      'prefill': {
        'contact': selectedAddress?["phone"] ?? "",
        'email': customer?["email"] ?? "",
      },
    };

    _razorpay.open(options);
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

    if (selectedAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Address missing")),
      );
      return;
    }

    double subtotalAfterDiscount = widget.totalAmount - couponDiscount;
    double shipping = calculateShipping(subtotalAfterDiscount);
    double finalAmount = subtotalAfterDiscount + shipping;

    /// ✅ FIX: Safe name parsing
    String fullName = selectedAddress?["name"]?.toString() ?? "Customer";
    List<String> nameParts = fullName.split(" ");

    String firstName = nameParts.isNotEmpty ? nameParts.first : "Customer";
    String lastName = nameParts.length > 1 ? nameParts.last : "";

    /// ✅ FIX: Get email from customer model (NOT address)
    final customer = context.read<CustomerModel>().customer;
    String email = customer?["email"] ?? "";

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

        "couponCode": appliedCoupon,
        "couponDiscount": couponDiscount,
        "shippingAmount": shipping,
        "totalMrp": widget.totalMrp,
        "productDiscount": widget.totalDiscount,
      }),
    );

    final data = jsonDecode(verify.body);

    if (data["success"]) {

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove("cart"); // 🔥 important
      showSuccessDialog();
    } else {

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(data["message"] ?? "Verification Failed")),
      );

    }
  }

  void handlePaymentError(PaymentFailureResponse response) {
    print("Payment Error ${response.message}");
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

    final customer = context.watch<CustomerModel>().customer;
    final userName = customer?['firstName'] ?? "Customer";
    /// ✅ GLOBAL CALCULATION (IMPORTANT)
    double subtotalAfterDiscount = widget.totalAmount - couponDiscount;
    double shipping = calculateShipping(subtotalAfterDiscount);
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
      final response = await http.get(
        Uri.parse("${BackendConfig.baseUrl}/shopify/coupons"),
      );
      List coupons = jsonDecode(response.body);
      final match = coupons.firstWhere(
            (c) => c["code"].toString().toUpperCase() == code,
        orElse: () => null,
      );
      if (match == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invalid Coupon")),
        );
        return;
      }
      applySelectedCoupon(match);
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
                      if (appliedCoupon != null)
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
                                "Applied: $appliedCoupon",
                                style: const TextStyle(color: Colors.green),
                              ),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    appliedCoupon = null;
                                    couponDiscount = 0;
                                  });
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

                      if (couponDiscount > 0) ...[
                        const SizedBox(height: 8),
                        _priceRow(
                          "Additional Discount",
                          "-${formatPrice(couponDiscount)}",
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

                      if (couponDiscount > 0) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "🎉 You saved ${formatPrice(couponDiscount)}",
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
