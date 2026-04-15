import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dotted_border/dotted_border.dart';

class CouponBottomSheet extends StatefulWidget {
  final double cartAmount;

  const CouponBottomSheet({super.key, required this.cartAmount});

  @override
  State<CouponBottomSheet> createState() => _CouponBottomSheetState();
}

class _CouponBottomSheetState extends State<CouponBottomSheet> {

  List coupons = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    fetchCoupons();
  }



  Future<void> fetchCoupons() async {
    final response = await http.get(
      Uri.parse("https://mm-backend-production-f67e.up.railway.app/api/shopify/coupons"),
    );

    if (response.statusCode == 200) {
      setState(() {
        coupons = jsonDecode(response.body);
        loading = false;
      });
    }
  }

  double sw(BuildContext context) => MediaQuery.of(context).size.width;
  double sh(BuildContext context) => MediaQuery.of(context).size.height;

  double scale(BuildContext context, double size) {
    return size * (sw(context) / 375); // 375 = base iPhone width
  }

  double calculateDiscount(Map coupon) {
    final type = coupon["discount_type"];
    final value = double.parse(
        coupon["value"].toString().replaceAll("-", "")
    );

    final minimum = coupon["minimum"] != null
        ? double.tryParse(coupon["minimum"].toString())
        : null;

    /// ❗ Minimum check
    if (minimum != null && widget.cartAmount < minimum) return 0;

    /// ✅ FIXED AMOUNT
    if (type == "fixed_amount") {
      return value;
    }

    /// ✅ PERCENTAGE
    if (type == "percentage") {

      /// 🎁 FREE GIFT CASE (100%)
      if (value == 100) {
        return 0; // ❗ DO NOT APPLY PRICE DISCOUNT
      }

      double discount = (widget.cartAmount * value) / 100;

      /// ✅ Optional max cap
      if (coupon["max_discount"] != null) {
        double max = double.parse(coupon["max_discount"].toString());
        if (discount > max) discount = max;
      }

      return discount;
    }

    return 0;
  }

  @override
  Widget build(BuildContext context) {

    if (loading) {
      return const SizedBox(
        height: 300,
        child: Center(child: CircularProgressIndicator()),
      );
    }



    return SafeArea(
        top: false, // 👈 only bottom safe
        child: SizedBox(
          height: sh(context) * 0.8,
    child: ListView.builder(
    padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 16, // 👈 key fix
     ),
    itemCount: coupons.length,
    itemBuilder: (context, index) {

          final coupon = coupons[index];
          double discount = calculateDiscount(coupon);

          bool isValid = discount > 0;

          String offerText = "";

          final type = coupon["discount_type"];
          final value =
          coupon["value"].toString().replaceAll("-", "").split(".")[0];

          final minimum = coupon["minimum"] != null
              ? double.tryParse(coupon["minimum"].toString())?.toInt()
              : null;

          /// ✅ Offer text logic
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
            onTap: isValid
                ? () => Navigator.pop(context, coupon)
                : null,
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: EdgeInsets.all(scale(context, 16)),
              decoration: BoxDecoration(
                color: isValid
                    ? const Color(0xFFFFF4F8)
                    : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded( // ✅ prevents overflow
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          offerText,
                          style: TextStyle(
                            fontSize: scale(context, 13),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: scale(context, 8)),

                        DottedBorder(
                          borderType: BorderType.RRect,
                          radius: Radius.circular(scale(context, 8)),
                          dashPattern: const [10, 2],
                          color: Colors.pink,
                          strokeWidth: 1.2,
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: scale(context, 8),
                              vertical: scale(context, 4),
                            ),
                            child: Text(
                              coupon["code"].toString().toUpperCase(),
                              style: TextStyle(
                                fontSize: scale(context, 12),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (isValid)
                    Text(
                      "APPLY",
                      style: TextStyle(
                        fontSize: scale(context, 13),
                        color: const Color(0xFFEA0180),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
        )
    );
  }
}