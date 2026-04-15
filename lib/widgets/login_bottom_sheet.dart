import 'package:flutter/material.dart';
import '../screens/login_screen_bottom.dart';

class LoginBottomSheet extends StatelessWidget {
  const LoginBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(20),
        ),

        /// 🔥 REUSE YOUR EXISTING SCREEN UI
        child: const CustomerLoginRegisterBottom(),
      ),
    );
  }
}