import 'package:flutter/material.dart';

class HomeHeroBanner extends StatelessWidget {
  const HomeHeroBanner({super.key});


  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      height: 240,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        image: const DecorationImage(
          image: NetworkImage(
            "https://images.unsplash.com/photo-1522335789203-aabd1fc54bc9",
          ),
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
