import 'package:flutter/material.dart';

class CategorySkeleton extends StatelessWidget {
  const CategorySkeleton({super.key});

  Widget _box({
    double height = 16,
    double width = double.infinity,
    double radius = 6,
  }) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  Widget _categoryItem() {
    return Column(
      children: [
        _box(height: 95, width: 95, radius: 10),
        const SizedBox(height: 8),
        _box(height: 12, width: 70),
      ],
    );
  }

  Widget _categoryGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 6,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 18,
        crossAxisSpacing: 18,
        childAspectRatio: 0.75,
      ),
      itemBuilder: (_, __) => _categoryItem(),
    );
  }

  Widget _section() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        /// Banner skeleton
        Container(
          height: 200,
          width: double.infinity,
          margin: const EdgeInsets.only(top: 16),
          color: Colors.grey.shade300,
        ),

        const SizedBox(height: 16),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _categoryGrid(),
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        /// Search bar skeleton
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          child: _box(height: 40, radius: 10),
        ),

        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                _section(),
                _section(),
                _section(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
