import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import '../widgets/app_icon.dart';
import 'package:dotted_border/dotted_border.dart';

class CouponsPage extends StatefulWidget {
  const CouponsPage({super.key});

  @override
  State<CouponsPage> createState() => _CouponsPageState();
}

class _CouponsPageState extends State<CouponsPage> {

  List coupons = [];
  bool loading = true;

  /// Check if coupon expired
  bool isExpired(String? startDate, String? endDate) {
    try {

      DateTime now = DateTime.now();

      if (startDate != null) {
        DateTime start = DateTime.parse(startDate);
        if (now.isBefore(start)) return true;
      }

      if (endDate != null) {
        DateTime end = DateTime.parse(endDate);
        if (now.isAfter(end)) return true;
      }

      return false;

    } catch (e) {
      return false;
    }
  }

  /// Fetch coupons from backend
  Future<void> fetchCoupons() async {
    try {
      final response = await http.get(
        Uri.parse("https://mm-backend-production-f67e.up.railway.app/api/shopify/coupons"),
      );

      if (response.statusCode == 200) {

        List data = jsonDecode(response.body);

        /// Sort coupons: Active first, Expired last
        data.sort((a, b) {

          bool aExpired = isExpired(a["starts_at"], a["ends_at"]);
          bool bExpired = isExpired(b["starts_at"], b["ends_at"]);

          if (aExpired == bExpired) return 0;
          if (aExpired) return 1;
          return -1;

        });

        setState(() {
          coupons = data;
          loading = false;
        });

      } else {
        setState(() => loading = false);
      }

    } catch (e) {
      setState(() => loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    fetchCoupons();
  }

  /// Copy coupon code
  void copyCode(String code) {
    Clipboard.setData(ClipboardData(text: code));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Coupon copied")),
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,


        title: const Text(
          'Coupons & Offers',
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
      body: loading
          ? const Center(child: CircularProgressIndicator())

          : coupons.isEmpty
          ? const Center(child: Text("No coupons available"))

          : ListView.builder(

        padding: const EdgeInsets.all(16),
        itemCount: coupons.length,

        itemBuilder: (context, index) {

          final coupon = coupons[index];

          bool expired = isExpired(
            coupon["starts_at"],
            coupon["ends_at"],
          );

          String offerText = "";

          final type = coupon["discount_type"];

          final value =
          coupon["value"].toString().replaceAll("-", "").split(".")[0];

          final minimum = coupon["minimum"] != null
              ? double.tryParse(coupon["minimum"].toString())?.toInt()
              : null;

          /// Offer text logic
          if (type == "fixed_amount") {

            if (minimum != null) {
              offerText =
              "🎉 Special Offer: Get ₹$value OFF on orders above ₹$minimum";
            } else {
              offerText =
              "🎉 Special Offer: Get ₹$value OFF on your order";
            }

          } else if (type == "percentage") {

            if (value == "100") {
              offerText = "🎁 Free Gift Offer: Get 1 item FREE";
            } else {
              offerText = "🔥 Special Offer: Get $value% OFF";
            }

          }

          return GestureDetector(
              onTap: expired
              ? null
              : () {
            Navigator.pop(context, coupon); // ✅ RETURN COUPON
          },
          child: Container(

            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),

            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: expired ? const Color(0xFFEFEFEF)  : const Color(0xFFFFF4F8),
              border: Border.all(
                color: expired ? Colors.grey : Colors.pink.shade200,
              ),
            ),

            child: Stack(
              children: [

                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    /// OFFER TEXT
                    Text(
                      offerText,
                      style: TextStyle(
                        fontSize: 14,

                        color: expired ? Colors.grey.shade700 : Colors.black,
                      ),
                    ),

                    const SizedBox(height: 10),

                    /// CODE ROW
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [

                        Row(
                          children: [

                            Text(
                              "Use Code: ",
                              style: TextStyle(
                                fontSize: 14,
                                color: expired ? Colors.grey.shade700 : Colors.black,
                              ),
                            ),
                            const SizedBox(width: 8),
                            DottedBorder(
                              borderType: BorderType.RRect,
                              radius: const Radius.circular(8),
                              dashPattern: const [10, 2],
                              color: expired ? Colors.grey : Colors.pink,
                              strokeWidth: 1.2,

                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),

                                child: Text(
                                  coupon["code"].toString().toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                    color: expired ? Colors.grey.shade700 : Colors.black,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        /// COPY BUTTON
                        if (!expired)
                          GestureDetector(
                            onTap: () => copyCode(coupon["code"]),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: Colors.pink,
                              ),
                              child: const Text(
                                "COPY",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),

                /// EXPIRED BADGE
                if (expired)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade700,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        "EXPIRED",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

              ],
            ),
          ),
          );
        },
      ),
    );
  }
}