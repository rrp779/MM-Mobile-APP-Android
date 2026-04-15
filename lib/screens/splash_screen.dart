import 'package:flutter/material.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {

  @override
  void initState() {
    super.initState();

    /// 🔥 Run after first frame (important for iOS)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      startApp();
    });
  }

  Future<void> startApp() async {
    try {
      /// optional delay
      await Future.delayed(const Duration(seconds: 2));
    } catch (e) {
      print("Splash error: $e");
    }

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [

          /// 🔥 SAFE IMAGE (no crash)
          Positioned.fill(
            child: Image.asset(
              'assets/splash.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Container(color: Colors.white), // 👈 fallback
            ),
          ),

          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.15),
            ),
          ),

          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/logo.png',
                  height: 90,
                  errorBuilder: (_, __, ___) =>
                  const SizedBox(), // 👈 prevent crash
                ),
                const SizedBox(height: 24),
                const CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Color(0xFFEA0180)),
                ),
              ],
            ),
          ),

          const Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: Text(
              'POWERED BY LIVEBLACK',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.black,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}