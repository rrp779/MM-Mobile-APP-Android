import 'package:flutter/material.dart';
import 'app_shimmer.dart';

class ProductCardSkeleton extends StatelessWidget {
  const ProductCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          AppShimmer(height: 140, radius: 12),
          SizedBox(height: 10),
          AppShimmer(height: 14, width: 120),
          SizedBox(height: 6),
          AppShimmer(height: 14, width: 80),
        ],
      ),
    );
  }
}
