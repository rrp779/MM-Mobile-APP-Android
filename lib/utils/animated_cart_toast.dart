import 'package:flutter/material.dart';

void showAnimatedCartToast(
    BuildContext context, {
      required bool added,
    }) {
  final overlay = Overlay.of(context);

  late OverlayEntry overlayEntry;

  overlayEntry = OverlayEntry(
    builder: (context) => _AnimatedCartToast(
      message: added
          ? "Product Added to Cart"
          : "Product Removed from Cart",
      icon: added
          ? Icons.shopping_bag
          : Icons.remove_shopping_cart,
      onFinish: () {
        overlayEntry.remove();
      },
    ),
  );

  overlay.insert(overlayEntry);
}

class _AnimatedCartToast extends StatefulWidget {
  final String message;
  final IconData icon;
  final VoidCallback onFinish;

  const _AnimatedCartToast({
    required this.message,
    required this.icon,
    required this.onFinish,
  });

  @override
  State<_AnimatedCartToast> createState() =>
      _AnimatedCartToastState();
}

class _AnimatedCartToastState extends State<_AnimatedCartToast>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<double> _slide;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _opacity =
        Tween<double>(begin: 0, end: 1).animate(_controller);

    _slide =
        Tween<double>(begin: 40, end: 0).animate(
          CurvedAnimation(
            parent: _controller,
            curve: Curves.easeOutBack, // 🔥 slight bounce
          ),
        );

    _controller.forward();

    Future.delayed(const Duration(seconds: 1), () async {
      await _controller.reverse();
      widget.onFinish();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 80,
      left: 40,
      right: 40,
      child: FadeTransition(
        opacity: _opacity,
        child: AnimatedBuilder(
          animation: _slide,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _slide.value),
              child: child,
            );
          },
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black
                        .withOpacity(0.25),
                    blurRadius: 20,
                    spreadRadius: 2,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    widget.icon,
                    color: Colors.green,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.message,
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight:
                        FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
