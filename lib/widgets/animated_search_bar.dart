import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/collection_provider.dart';
import '../screens/search_screen.dart';
import 'app_icon.dart';
class AnimatedSearchBar extends StatefulWidget {
  const AnimatedSearchBar({super.key});

  @override
  State<AnimatedSearchBar> createState() =>
      _AnimatedSearchBarState();
}

class _AnimatedSearchBarState
    extends State<AnimatedSearchBar> {
  int _wordIndex = 0;
  int _charIndex = 0;

  Timer? _typingTimer;
  Timer? _wordChangeTimer;

  String _displayText = "";

  final TextEditingController _controller =
  TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      context
          .read<CollectionProvider>()
          .fetchCollections();
    });

    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        _stopTyping();
      } else {
        _startTyping();
      }
    });

    _startTyping();
  }

  void _startTyping() {
    _typingTimer?.cancel();
    _wordChangeTimer?.cancel();

    final provider =
    context.read<CollectionProvider>();

    final categories = provider.categories.isEmpty
        ? ["Foundation"]
        : provider.categories;

    final currentWord =
    categories[_wordIndex % categories.length];

    _charIndex = 0;
    _displayText = "";

    _typingTimer = Timer.periodic(
      const Duration(milliseconds: 80),
          (timer) {
        if (_focusNode.hasFocus) return;

        if (_charIndex < currentWord.length) {
          setState(() {
            _displayText +=
            currentWord[_charIndex];
            _charIndex++;
          });
        } else {
          timer.cancel();

          _wordChangeTimer =
              Timer(const Duration(seconds: 1), () {
                setState(() {
                  _displayText = "";
                });

                Future.delayed(
                  const Duration(milliseconds: 300),
                      () {
                    setState(() {
                      _wordIndex++;
                    });
                    _startTyping();
                  },
                );
              });
        }
      },
    );
  }

  void _stopTyping() {
    _typingTimer?.cancel();
    _wordChangeTimer?.cancel();
    setState(() {
      _displayText = "";
    });
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _wordChangeTimer?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const SearchScreen(),
            ),
          );
        },
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            color:Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: const Color(0xFFEFEFEF),
              width: 1,
            ),
          ),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [

              /// Fake TextField (UI Only)
              const TextField(
                enabled: false,
                decoration: InputDecoration(
                  prefixIcon: Padding(
                    padding: const EdgeInsets.all(12),
                    child: AppIcon(
                      isActive: false,
                      outlinePath: 'assets/icons/SearchOutline.svg',
                      filledPath: 'assets/icons/SearchBold.svg',
                      size: 20,
                    ),
                  ),
                  border: InputBorder.none,
                ),
              ),

              /// Animated Hint Text
              Positioned(
                left: 48,
                child: Row(
                  children: [
                    const Text(
                      "Search For ",
                      style: TextStyle(color: Colors.grey),
                    ),
                    Text(
                      _displayText,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}
