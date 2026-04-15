import 'package:flutter/material.dart';
import 'app_shimmer.dart';

class ProductDetailSkeleton extends StatelessWidget {
  const ProductDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: const [
          AppShimmer(height: 400, radius: 0),
          SizedBox(height: 20),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppShimmer(height: 22, width: 200),
                SizedBox(height: 10),
                AppShimmer(height: 20, width: 120),
                SizedBox(height: 20),
                AppShimmer(height: 16),
                SizedBox(height: 6),
                AppShimmer(height: 16),
                SizedBox(height: 6),
                AppShimmer(height: 16),
              ],
            ),
          )
        ],
      ),
    );
  }
}
