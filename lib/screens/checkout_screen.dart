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
import '../services/notification_service.dart';

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
  String? _currentRazorpayOrderId;
  bool _isProcessingPayment = false;
  bool _isCreatingOrder = false;
  Map<String, dynamic>? _confirmedOrder;
  String? _confirmedPaymentId;
  String? _paymentErrorMessage;
  double _confirmedCouponDiscount = 0.0;
  double _confirmedShipping = 0.0;
  double _confirmedFinalAmount = 0.0;

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

  double calculateShipping() {
    double shipping = 0;
    bool hasRegularProduct = false;

    for (var item in widget.cartItems) {
      final handle = (item["handle"] ?? "").toString().trim().toLowerCase();
      final qty = (item["qty"] ?? 1) as int;

      if (handle == "portable-makeup-artist-chair-with-headrest") {
        shipping += 300 * qty;
      } else if (handle == "premium-edition-vanity-bag-with-6-pouches" ||
          handle == "makeup-mystery-vanity-bag-with-6-pouches" ||
          handle == "beyond-vanity-bag" ||
          handle == "makeup-mystery-hair-makeup-vanity-bag-with-4-pouches" ||
          handle == "beyond-box-makeup-vanity") {
        shipping += 480 * qty;
      } else {
        hasRegularProduct = true;
      }
    }

    if (hasRegularProduct) {
      shipping += 80;
    }

    return shipping;
  }

  /// OPEN RAZORPAY
  Future<void> openCheckout() async {
    if (_isCreatingOrder) return;

    if (selectedAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please select delivery address"))
      );
      return;
    }

    final phoneRaw = (selectedAddress?["phone"] ?? "").toString().trim();
    final digits = phoneRaw.replaceAll(RegExp(r'\D'), '');
    final last10 = digits.length >= 10 ? digits.substring(digits.length - 10) : digits;
    if (last10.isEmpty || last10.length != 10 || !RegExp(r'^[6-9]\d{9}$').hasMatch(last10)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please provide a valid 10-digit mobile number for delivery"),
          backgroundColor: Color(0xFFE11D48),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isCreatingOrder = true;
    });

    /// ✅ USE SAME CALCULATION
    final cartProvider = context.read<CartProvider>();
    double subtotalAfterDiscount = widget.totalAmount - cartProvider.couponDiscount;
    double shipping = calculateShipping();
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
            "handle": item["handle"],
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
        'name': 'Makeup Mystery',
        'description': 'Order Payment',
        'image': razorpayLogoUrl,
        'timeout': 300,
        'prefill': {
          'contact': last10,
          'email': customer?["email"] ?? "",
        },
      };

      _currentRazorpayOrderId = data['id']?.toString();
      _razorpay.open(options);
    } catch (e) {
      debugPrint("Checkout openCheckout error: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error starting payment: $e"),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingOrder = false;
        });
      }
    }
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
      double shipping = calculateShipping();
      double finalAmount = subtotalAfterDiscount + shipping;
      final appliedCoupon = (cartProvider.appliedCoupon ?? couponController.text)
          .toString()
          .trim()
          .toUpperCase();

      // Lock in confirmed pricing numbers
      _confirmedCouponDiscount = cartProvider.couponDiscount;
      _confirmedShipping = shipping;
      _confirmedFinalAmount = finalAmount;

      // IMMEDIATELY switch to full-screen processing state
      // This guarantees the payment page and 'Pay Now' button NEVER reappear!
      setState(() {
        _isProcessingPayment = true;
        _confirmedPaymentId = response.paymentId;
        _paymentErrorMessage = null;
      });

      String fullName = selectedAddress?["name"]?.toString() ?? "Customer";
      List<String> nameParts = fullName.split(" ");

      String firstName = nameParts.isNotEmpty ? nameParts.first : "Customer";
      String lastName = nameParts.length > 1 ? nameParts.last : "";

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

          "couponCode": appliedCoupon.isEmpty ? null : appliedCoupon,
          "couponDiscount": cartProvider.couponDiscount,
          "shippingAmount": shipping,
          "totalMrp": widget.totalMrp,
          "productDiscount": widget.totalDiscount,
        }),
      );

      final data = jsonDecode(verify.body);

      if (data["success"] == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove("cart"); // 🔥 important
        cartProvider.resetCartState();
        couponController.clear();

        NotificationService().syncTokenWithBackend(
          phone: selectedAddress?["phone"]?.toString(),
          email: email,
          customerId: data["order"]?["customer"]?["id"]?.toString(),
        );

        if (mounted) {
          setState(() {
            _isProcessingPayment = false;
            _confirmedOrder = data["order"] is Map
                ? Map<String, dynamic>.from(data["order"])
                : {"id": response.orderId, "name": "Order Confirmed"};
          });
        }
      } else {
        final details = data["details"];
        final detailsText = (details == null)
            ? null
            : (details is String)
                ? details
                : details.toString();

        if (mounted) {
          setState(() {
            _isProcessingPayment = false;
            _paymentErrorMessage = detailsText?.isNotEmpty == true
                ? detailsText!
                : (data["message"] ?? "Payment verified, but order creation failed. Please contact support.");
          });
        }
      }
    } catch (e) {
      debugPrint("handlePaymentSuccess error: $e");
      cartProvider.resetCartState();
      if (mounted) {
        setState(() {
          _isProcessingPayment = false;
          _paymentErrorMessage =
              "Payment completed (Payment ID: ${_confirmedPaymentId ?? 'N/A'}), but order confirmation encountered an issue. Please contact support.";
        });
      }
    }
  }

  Widget _buildProcessingPaymentView() {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFDE7F3),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: CircularProgressIndicator(
                        strokeWidth: 3.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEA0180)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  "Payment Received!",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                const Text(
                  "Verifying your payment and confirming your order with Shopify...",
                  style: TextStyle(
                    fontSize: 15,
                    color: Color(0xFF6B7280),
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    children: const [
                      Icon(
                        Icons.info_outline,
                        color: Color(0xFFD97706),
                        size: 22,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Please do not close or exit the app. This will take only a few seconds.",
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF92400E),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_confirmedPaymentId != null) ...[
                  const SizedBox(height: 20),
                  Text(
                    "Payment ID: $_confirmedPaymentId",
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrderConfirmationView() {
    final orderName = _confirmedOrder?["name"]?.toString() ??
        (_confirmedOrder?["order_number"] != null
            ? "#${_confirmedOrder!["order_number"]}"
            : "Confirmed");
    final shippingAddr = _confirmedOrder?["shipping_address"] as Map<String, dynamic>?;
    final recipientName = shippingAddr?["name"] ??
        "${shippingAddr?["first_name"] ?? ''} ${shippingAddr?["last_name"] ?? ''}".trim();
    final addressLine = [
      shippingAddr?["address1"] ?? selectedAddress?["address1"],
      shippingAddr?["address2"] ?? selectedAddress?["address2"],
      shippingAddr?["city"] ?? selectedAddress?["city"],
      shippingAddr?["province"] ?? selectedAddress?["province"] ?? selectedAddress?["state"],
      shippingAddr?["zip"] ?? selectedAddress?["zip"] ?? selectedAddress?["pincode"],
    ].where((e) => e != null && e.toString().trim().isNotEmpty).join(", ");
    final recipientPhone = shippingAddr?["phone"] ?? selectedAddress?["phone"] ?? "";

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF9FAFB),
        appBar: AppBar(
          title: const Text(
            "Order Confirmed",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.white,
          elevation: 0.5,
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              tooltip: "Go to Home",
              icon: const Icon(Icons.close, color: Colors.black87),
              onPressed: () {
                Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
              },
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Success Banner Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0x0A000000),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle_rounded,
                        color: Colors.green,
                        size: 48,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Thank you for your order!",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111827),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "Your order has been placed and is being processed.",
                      style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            "Order ",
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF4B5563),
                            ),
                          ),
                          Text(
                            orderName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFEA0180),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_confirmedPaymentId != null && _confirmedPaymentId!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        "Payment ID: $_confirmedPaymentId",
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 2. Items Ordered Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0x0A000000),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(
                          Icons.shopping_bag_outlined,
                          size: 20,
                          color: Color(0xFFEA0180),
                        ),
                        SizedBox(width: 8),
                        Text(
                          "Items Ordered",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: widget.cartItems.length,
                      separatorBuilder: (_, __) => const Divider(height: 20),
                      itemBuilder: (context, index) {
                        final item = widget.cartItems[index];
                        final imgUrl = item["image"]?.toString() ?? "";
                        final title = item["title"]?.toString() ?? "Product";
                        final qty = item["qty"] ?? 1;
                        final price = (item["price"] is num)
                            ? (item["price"] as num).toDouble()
                            : double.tryParse(item["price"]?.toString() ?? "0") ?? 0.0;

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: 56,
                                height: 56,
                                color: Colors.grey.shade100,
                                child: imgUrl.isNotEmpty
                                    ? Image.network(
                                        imgUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => const Icon(
                                          Icons.image_not_supported_outlined,
                                          color: Colors.grey,
                                          size: 24,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.shopping_bag_outlined,
                                        color: Colors.grey,
                                        size: 24,
                                      ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1F2937),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Qty: $qty",
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF6B7280),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              formatPrice(price * qty),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF111827),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 3. Delivery Address Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0x0A000000),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(
                          Icons.location_on_outlined,
                          size: 20,
                          color: Color(0xFFEA0180),
                        ),
                        SizedBox(width: 8),
                        Text(
                          "Delivery Address",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    if (recipientName.isNotEmpty)
                      Text(
                        recipientName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                    const SizedBox(height: 4),
                    if (addressLine.isNotEmpty)
                      Text(
                        addressLine,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF4B5563),
                          height: 1.4,
                        ),
                      ),
                    if (recipientPhone.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.phone_outlined, size: 14, color: Color(0xFF6B7280)),
                          const SizedBox(width: 6),
                          Text(
                            recipientPhone,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF4B5563),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 4. Price Breakdown Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0x0A000000),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(
                          Icons.receipt_outlined,
                          size: 20,
                          color: Color(0xFFEA0180),
                        ),
                        SizedBox(width: 8),
                        Text(
                          "Price Details",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    _priceRow("Total MRP", formatPrice(widget.totalMrp)),
                    const SizedBox(height: 10),
                    _priceRow("Bag Discount", "- ${formatPrice(widget.totalDiscount)}", valueColor: Colors.green),
                    if (_confirmedCouponDiscount > 0) ...[
                      const SizedBox(height: 10),
                      _priceRow("Coupon Discount", "- ${formatPrice(_confirmedCouponDiscount)}", valueColor: Colors.green),
                    ],
                    const SizedBox(height: 10),
                    _priceRow("Shipping", _confirmedShipping == 0 ? "FREE" : formatPrice(_confirmedShipping)),
                    const Divider(height: 24),
                    _priceRow("Total Paid", formatPrice(_confirmedFinalAmount), isBold: true),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // 5. Action Buttons
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEA0180),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const CustomerOrders()),
                    (route) => false,
                  );
                },
                child: const Text(
                  "View My Orders",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  side: const BorderSide(color: Color(0xFFEA0180)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
                },
                child: const Text(
                  "Continue Shopping",
                  style: TextStyle(
                    color: Color(0xFFEA0180),
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentErrorView() {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Order Status", style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            setState(() {
              _paymentErrorMessage = null;
            });
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: Colors.amber,
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "Order Processing Issue",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              _paymentErrorMessage ?? "Payment was received, but we encountered an issue while finalizing your order.",
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            if (_confirmedPaymentId != null) ...[
              const SizedBox(height: 12),
              Text(
                "Payment ID: $_confirmedPaymentId",
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF4B5563),
                ),
              ),
            ],
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEA0180),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const CustomerOrders()),
                    (route) => false,
                  );
                },
                child: const Text(
                  "Check My Orders",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
                },
                child: const Text("Return to Home"),
              ),
            ),
          ],
        ),
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

  void handlePaymentError(PaymentFailureResponse response) {
    if (!mounted) return;
    final msg = (response.message?.isNotEmpty ?? false)
        ? response.message!
        : "Payment was not completed. Your items are safe in your cart.";
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );

    if (_currentRazorpayOrderId != null && _currentRazorpayOrderId!.isNotEmpty) {
      final customer = context.read<CustomerModel>().customer;
      http.post(
        Uri.parse("${BackendConfig.baseUrl}/payment/failed"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "razorpay_order_id": _currentRazorpayOrderId,
          "error_code": response.code,
          "error_description": response.message ?? "Payment cancelled by user",
          "email": customer?["email"] ?? "",
          "phone": selectedAddress?["phone"]?.toString() ?? "",
        }),
      ).catchError((_) => http.Response('', 500));
    }
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
    if (_isProcessingPayment) {
      return _buildProcessingPaymentView();
    }

    if (_confirmedOrder != null) {
      return _buildOrderConfirmationView();
    }

    if (_paymentErrorMessage != null) {
      return _buildPaymentErrorView();
    }

    if (isLoadingUser) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final cartProvider = context.watch<CartProvider>();
    final customer = context.watch<CustomerModel>().customer;
    final userName = customer?['firstName'] ?? "Customer";
    /// ✅ GLOBAL CALCULATION (IMPORTANT)
    double subtotalAfterDiscount = widget.totalAmount - cartProvider.couponDiscount;
    double shipping = calculateShipping();
    double finalAmount = subtotalAfterDiscount + shipping;
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
                    onPressed: _isCreatingOrder ? null : openCheckout,
                    child: _isCreatingOrder
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
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
